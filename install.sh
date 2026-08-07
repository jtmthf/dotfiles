#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=lib/logging.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/logging.sh"

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
            echo "wsl"
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
DRY_RUN=false
ROLLBACK=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --rollback) ROLLBACK=true ;;
        -h|--help) echo "Usage: install.sh [--dry-run] [--rollback]"; exit 0 ;;
        *) log_error "Unknown argument: $arg"; exit 1 ;;
    esac
done

# Run a command, or just log it in dry-run mode
run() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] $*"
    else
        "$@"
    fi
}

log_info "Detected OS: $OS"
log_info "Dotfiles directory: $DOTFILES_DIR"
$DRY_RUN && log_warning "Dry-run mode: no changes will be made"

# Create backup directory
$DRY_RUN || mkdir -p "$BACKUP_DIR"

# Unified safe-link: backup existing file/dir/symlink at dst, then link src→dst.
# Idempotent: if dst is already a symlink pointing to src, do nothing.
# Args: <src> <dst> [backup_name]
safe_link() {
    local src="$1" dst="$2"
    local backup_name="${3:-$(basename "$dst")}"

    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        log_info "Already linked: $dst"
        return
    fi

    if [[ -e "$dst" || -L "$dst" ]]; then
        log_info "Backing up existing $(basename "$dst")"
        run mv "$dst" "$BACKUP_DIR/$backup_name"
    fi

    run mkdir -p "$(dirname "$dst")"
    run ln -sf "$src" "$dst"
}

# Guarantee ~/.dotfiles points at this checkout. The zsh config (aliases,
# functions, plugin loading) resolves the repo via ~/.dotfiles, so the repo
# may be cloned anywhere as long as this link exists.
setup_dotfiles_link() {
    if [[ "$DOTFILES_DIR" == "$HOME/.dotfiles" ]]; then
        return
    fi
    if [[ -L "$HOME/.dotfiles" ]]; then
        if [[ "$(readlink "$HOME/.dotfiles")" == "$DOTFILES_DIR" ]]; then
            # shellcheck disable=SC2088  # literal description string, not path expansion
            log_info "~/.dotfiles already links to $DOTFILES_DIR"
            return
        fi
        run ln -sfn "$DOTFILES_DIR" "$HOME/.dotfiles"
    elif [[ -e "$HOME/.dotfiles" ]]; then
        # shellcheck disable=SC2088  # literal description string, not path expansion
        log_error "~/.dotfiles exists and is not a symlink. Move it aside or clone the repo there directly."
        exit 1
    else
        run ln -s "$DOTFILES_DIR" "$HOME/.dotfiles"
    fi
    log_success "Linked ~/.dotfiles -> $DOTFILES_DIR"
}

# Install Homebrew
install_homebrew() {
    if ! command -v brew &> /dev/null; then
        log_info "Installing Homebrew..."
        if [[ "$DRY_RUN" == true ]]; then
            log_info "[DRY RUN] Would install Homebrew for $OS"
        elif [[ "$OS" == "macos" ]]; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            # Linux/WSL
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
            # shellcheck disable=SC2016  # intentionally write literal $() command into .profile
            echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.profile"
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
        log_success "Homebrew installed"
    else
        log_info "Homebrew already installed"
    fi
}

# Install packages from Brewfile
install_packages() {
    if [[ -n "${SKIP_BREW_BUNDLE:-}" ]]; then
        log_info "Skipping brew bundle (SKIP_BREW_BUNDLE is set)"
        return
    fi
    log_info "Installing packages from Brewfile..."
    if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
        # Homebrew refuses to load formulae from untrusted third-party taps, which
        # aborts the whole bundle. Trust the taps the Brewfile declares so the
        # install runs unattended. (Guarded: `brew trust` is a newer subcommand.)
        if brew commands 2>/dev/null | grep -qx trust; then
            local tap
            while IFS= read -r tap; do
                [[ -n "$tap" ]] || continue
                run brew tap "$tap" || true
                run brew trust "$tap" || true
            done < <(grep -E '^[[:space:]]*tap[[:space:]]+"' "$DOTFILES_DIR/Brewfile" | sed -E 's/.*"([^"]+)".*/\1/')
        fi
        run brew bundle --file="$DOTFILES_DIR/Brewfile"
        log_success "Packages installed"
    else
        log_error "Brewfile not found"
        exit 1
    fi
}

# Setup zsh plugins
setup_zsh_plugins() {
    log_info "Setting up zsh plugins..."
    local plugins_dir="$DOTFILES_DIR/zsh/plugins"
    mkdir -p "$plugins_dir"
    
    # Clone plugins if they don't exist
    if [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
        run git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"
    fi

    if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
        run git clone https://github.com/zsh-users/zsh-autosuggestions.git "$plugins_dir/zsh-autosuggestions"
    fi

    if [[ ! -d "$plugins_dir/zsh-completions" ]]; then
        run git clone https://github.com/zsh-users/zsh-completions.git "$plugins_dir/zsh-completions"
    fi
    
    log_success "Zsh plugins setup complete"
}

# Setup tmux config + TPM (tmux plugin manager)
setup_tmux() {
    log_info "Setting up tmux config..."

    safe_link "$DOTFILES_DIR/config/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
    run mkdir -p "$HOME/.config/tmux/plugins"

    # Bootstrap TPM. Plugins themselves install on first `prefix + I`.
    if [[ ! -d "$HOME/.config/tmux/plugins/tpm" ]]; then
        run git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.config/tmux/plugins/tpm"
        log_info "TPM installed. Open tmux, then press prefix + I to install plugins"
    fi

    log_success "tmux config setup complete"
}

# Setup cw (worktree-backed tmux/Claude sessions). Make the scripts and hooks
# executable; the `cw` shell function invokes them by path (no PATH entry needed).
setup_cw() {
    log_info "Setting up cw (worktree sessions)..."

    run chmod +x "$DOTFILES_DIR/scripts/cw/cw" "$DOTFILES_DIR/scripts/cw/cw-lib.sh"
    [[ -f "$DOTFILES_DIR/scripts/cw/cw-dashboard.sh" ]] && run chmod +x "$DOTFILES_DIR/scripts/cw/cw-dashboard.sh"
    # Claude hooks (the "agent is waiting" markers) live alongside cw; make any present ones executable.
    if compgen -G "$DOTFILES_DIR/scripts/cw/hooks/*.sh" > /dev/null; then
        run chmod +x "$DOTFILES_DIR"/scripts/cw/hooks/*.sh
    fi

    log_success "cw setup complete"
}

# Merge the repo's Claude settings.json into ~/.claude/settings.json non-destructively.
# Semantics:
#   - Deep object merge; live file wins on key conflicts
#   - Arrays at .permissions.allow and .permissions.deny are union-ed (live first, then repo entries not already present)
#   - Pre-merge live file is backed up once per install run
# This is NOT a symlink — Claude Code mutates settings.json (plugin toggles, /config),
# so we leave the live file authoritative and only top up shareable baseline entries.
merge_claude_settings() {
    local repo_settings="$DOTFILES_DIR/config/claude/settings.json"
    local live_settings="$HOME/.claude/settings.json"

    if ! command -v jq &> /dev/null; then
        log_error "jq is required to merge Claude settings.json"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would jq-merge $repo_settings into $live_settings (live wins on conflicts)"
        return
    fi

    # Seed an empty object if the live file doesn't exist yet
    if [[ ! -f "$live_settings" ]]; then
        echo '{}' > "$live_settings"
    else
        cp "$live_settings" "$BACKUP_DIR/claude_settings.json.pre-merge"
    fi

    local tmp
    tmp=$(mktemp)
    jq -n \
        --slurpfile repo "$repo_settings" \
        --slurpfile live "$live_settings" '
            def union_keep_order(a; b):
                (a // []) as $a | (b // []) as $b | $a + ($b - $a);
            ($repo[0] * $live[0])
            | .permissions.allow = union_keep_order($live[0].permissions.allow; $repo[0].permissions.allow)
            | .permissions.deny  = union_keep_order($live[0].permissions.deny;  $repo[0].permissions.deny)
        ' > "$tmp"

    mv "$tmp" "$live_settings"
    log_info "Merged Claude settings.json (live retained on conflicts)"
}

# Setup Claude Code config
setup_claude() {
    log_info "Setting up Claude Code config..."

    local claude_dir="$HOME/.claude"
    run mkdir -p "$claude_dir"

    merge_claude_settings
    run chmod +x "$DOTFILES_DIR/config/claude/statusline.sh"
    safe_link "$DOTFILES_DIR/config/claude/statusline.sh" "$claude_dir/statusline.sh" "claude_statusline.sh"

    log_success "Claude Code config setup complete"
}

# Create symlinks
create_symlinks() {
    log_info "Creating symlinks..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would write $HOME/.zshenv (bootstrap)"
        log_info "[DRY RUN] Would safe_link: zsh/.zshenv, zsh/.zprofile, zsh/.zshrc"
        log_info "[DRY RUN] Would safe_link: starship.toml, mise/config.toml, ghostty/config, sesh/sesh.toml"
        log_info "[DRY RUN] Would safe_link: opencode/, git/config, git/ignore, zed/settings.json, gh/config.yml"
        log_info "[DRY RUN] Would safe_link: claude/CLAUDE.md, claude/TMUX.md, claude/SEARCH.md, claude/WEB.md, claude/DELEGATION.md, claude/statusline.sh"
        log_info "[DRY RUN] Would prepend Include to ~/.ssh/config and write ~/.ssh/config.local"
        return
    fi

    # Bootstrap .zshenv — written, not symlinked, so zsh finds ZDOTDIR early
    cat > "$HOME/.zshenv" << 'ZSHENV'
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:=${HOME}/.config}
export ZDOTDIR=${ZDOTDIR:=${XDG_CONFIG_HOME}/zsh}
source $ZDOTDIR/.zshenv
ZSHENV

    # Zsh config symlinks
    safe_link "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.config/zsh/.zshenv"
    safe_link "$DOTFILES_DIR/zsh/.zprofile" "$HOME/.config/zsh/.zprofile"
    safe_link "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.config/zsh/.zshrc"

    # Starship config
    safe_link "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"

    # Mise config
    safe_link "$DOTFILES_DIR/config/mise/config.toml" "$HOME/.config/mise/config.toml"

    # Ghostty config
    safe_link "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"

    # Sesh config (tmux session manager)
    safe_link "$DOTFILES_DIR/config/sesh/sesh.toml" "$HOME/.config/sesh/sesh.toml"

    # OpenCode config (directory symlink)
    safe_link "$DOTFILES_DIR/config/opencode" "$HOME/.config/opencode" "opencode"

    # SSH config — written as a real file (not a symlink) so tools like
    # 1Password can append host entries without touching source-controlled files.
    mkdir -p "$HOME/.ssh" "$HOME/.ssh/control"
    chmod 700 "$HOME/.ssh" "$HOME/.ssh/control"
    local ssh_include="Include $DOTFILES_DIR/config/ssh/config"
    if [[ -L "$HOME/.ssh/config" ]]; then
        rm -f "$HOME/.ssh/config"
    fi
    if [[ ! -f "$HOME/.ssh/config" ]]; then
        printf '%s\n' "$ssh_include" > "$HOME/.ssh/config"
        chmod 600 "$HOME/.ssh/config"
    elif ! grep -qF "$ssh_include" "$HOME/.ssh/config"; then
        # Real file exists (e.g. has 1Password entries) — prepend Include, preserve content
        local tmp
        tmp=$(mktemp)
        { printf '%s\n' "$ssh_include"; cat "$HOME/.ssh/config"; } > "$tmp"
        mv "$tmp" "$HOME/.ssh/config"
        chmod 600 "$HOME/.ssh/config"
    fi
    # If Include is already present, leave the file untouched (idempotent)

    # Write platform-specific SSH config.local (avoids exec uname per connection)
    if [[ "$OS" == "macos" ]]; then
        printf 'Host *\n  IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"\n' > "$HOME/.ssh/config.local"
    else
        printf 'Host *\n  IdentityAgent "~/.1password/agent.sock"\n' > "$HOME/.ssh/config.local"
    fi

    # Ensure allowed_signers file exists for git commit verification
    touch "$HOME/.ssh/allowed_signers"

    # Git config
    safe_link "$DOTFILES_DIR/config/git/config" "$HOME/.config/git/config" "git_config"
    safe_link "$DOTFILES_DIR/config/git/ignore" "$HOME/.config/git/ignore" "git_ignore"
    # Ensure local overrides file exists (user.name, user.email, user.signingKey)
    [[ -f "$HOME/.config/git/config.local" ]] || touch "$HOME/.config/git/config.local"

    log_success "Symlinks created"
}

# Setup Zed config
setup_zed() {
    log_info "Setting up Zed config..."
    safe_link "$DOTFILES_DIR/config/zed/settings.json" "$HOME/.config/zed/settings.json" "zed_settings.json"
    log_success "Zed config setup complete"
}

# Setup gh (GitHub CLI) config
setup_gh() {
    log_info "Setting up gh config..."
    safe_link "$DOTFILES_DIR/config/gh/config.yml" "$HOME/.config/gh/config.yml" "gh_config.yml"
    log_success "gh config setup complete"
}

# Setup playwright-cli global skills for Claude Code
setup_playwright_cli() {
    log_info "Setting up playwright-cli skills..."
    if command -v playwright-cli &>/dev/null; then
        run playwright-cli install --skills
        log_success "playwright-cli skills installed"
    else
        log_warning "playwright-cli not found — run 'npm install -g @playwright/cli && playwright-cli install --skills' manually"
    fi
}

# Setup crawl4ai (downloads Playwright browsers)
setup_crawl4ai() {
    log_info "Setting up crawl4ai..."
    if command -v crawl4ai-setup &>/dev/null; then
        run crawl4ai-setup
        log_success "crawl4ai setup complete"
    else
        log_warning "crawl4ai-setup not found — run 'pip install crawl4ai && crawl4ai-setup' manually"
    fi
}

# Setup Colima
setup_colima() {
    log_info "Setting up Colima..."
    if [[ -f "$DOTFILES_DIR/scripts/setup-colima.zsh" ]]; then
        run zsh "$DOTFILES_DIR/scripts/setup-colima.zsh"
    fi
}

# Write a launchd agent plist for a weekly maintenance job (Sunday, hour:min).
_write_launchd_plist() {
    local plist="$1" label="$2" name="$3" hour="$4" min="$5" log_dir="$6"
    cat > "$plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$DOTFILES_DIR/scripts/maintenance/$name.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key><integer>0</integer>
        <key>Hour</key><integer>$hour</integer>
        <key>Minute</key><integer>$min</integer>
    </dict>
    <key>StartInterval</key>
    <integer>21600</integer>
    <key>StandardOutPath</key>
    <string>$log_dir/$name.log</string>
    <key>StandardErrorPath</key>
    <string>$log_dir/$name.err.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
PLIST
}

# Install the managed crontab block for maintenance jobs (Linux/WSL).
# Args: <log_dir> then "name hour min" job specs.
_install_maint_cron() {
    local log_dir="$1"; shift
    if ! command -v crontab &> /dev/null; then
        log_warning "crontab not found — skipping maintenance scheduling"
        return
    fi

    local block name hour min
    block="# >>> dotfiles-maint >>>"$'\n'
    block+="# Managed by dotfiles install.sh — edit config/maintenance/config.sh, not here."$'\n'
    block+="# Polls every 6h; each job does real work at most once per MAINT_MIN_INTERVAL_DAYS,"$'\n'
    block+="# so a run missed while the machine was off happens the next time it is on."$'\n'
    for job in "$@"; do
        # hour is only used by the launchd calendar slot; cron polls every 6h.
        # shellcheck disable=SC2034
        read -r name hour min <<< "$job"
        block+="$min */6 * * * /bin/bash $DOTFILES_DIR/scripts/maintenance/$name.sh >> $log_dir/$name.log 2>&1"$'\n'
    done
    block+="# <<< dotfiles-maint <<<"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would install dotfiles-maint crontab block:"
        printf '%s\n' "$block"
        return
    fi

    local current
    current=$(crontab -l 2>/dev/null | awk '/# >>> dotfiles-maint >>>/{s=1} !s; /# <<< dotfiles-maint <<</{s=0}')
    printf '%s\n%s\n' "$current" "$block" | crontab -
    log_success "Maintenance cron installed"
}

# Setup scheduled maintenance jobs (node_modules / worktrees / caches / trash)
setup_maintenance() {
    log_info "Setting up scheduled maintenance jobs..."

    run chmod +x "$DOTFILES_DIR"/scripts/maintenance/*.sh

    local log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-maint/logs"
    run mkdir -p "$log_dir"

    # Weekly schedule (Sunday), staggered: "name hour minute"
    local jobs=(
        "clean-node-modules 3 0"
        "clean-worktrees 3 30"
        "clean-caches 4 0"
        "empty-trash 4 30"
    )

    if [[ "$OS" == "macos" ]]; then
        local agents_dir="$HOME/Library/LaunchAgents"
        run mkdir -p "$agents_dir"
        local job name hour min label plist
        for job in "${jobs[@]}"; do
            read -r name hour min <<< "$job"
            label="com.jackmoore.maint.$name"
            plist="$agents_dir/$label.plist"
            if [[ "$DRY_RUN" == true ]]; then
                log_info "[DRY RUN] Would write $plist and load $label (Sun ${hour}:$(printf '%02d' "$min"))"
                continue
            fi
            launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
            _write_launchd_plist "$plist" "$label" "$name" "$hour" "$min" "$log_dir"
            launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null \
                || launchctl load "$plist" 2>/dev/null \
                || log_warning "Could not load $label"
        done
        log_success "launchd maintenance agents installed"
    else
        _install_maint_cron "$log_dir" "${jobs[@]}"
    fi
}

# Rollback from most recent backup
rollback() {
    local latest_backup
    # shellcheck disable=SC2012  # intentional: pick newest backup dir by mtime via glob
    latest_backup=$(ls -dt "$HOME"/.dotfiles_backup_* 2>/dev/null | head -1)

    if [[ -z "$latest_backup" ]]; then
        log_error "No backup directory found"
        exit 1
    fi

    log_info "Rolling back from: $latest_backup"

    # Remove symlinks
    rm -f "$HOME/.config/zsh/.zshenv" "$HOME/.config/zsh/.zprofile" "$HOME/.config/zsh/.zshrc"
    rm -f "$HOME/.config/starship.toml" "$HOME/.config/mise/config.toml"
    rm -f "$HOME/.config/ghostty/config"
    rm -f "$HOME/.config/sesh/sesh.toml"
    rm -f "$HOME/.config/opencode"
    rm -f "$HOME/.config/tmux/tmux.conf"
    rm -rf "$HOME/.config/tmux/plugins/tpm"
    rm -f "$HOME/.config/zed/settings.json"
    rm -f "$HOME/.config/gh/config.yml"
    # settings.json is a real merged file, not a symlink — leave it in place and let the pre-merge restore (below) decide
    rm -f "$HOME/.claude/CLAUDE.md" "$HOME/.claude/TMUX.md" "$HOME/.claude/SEARCH.md" "$HOME/.claude/WEB.md" "$HOME/.claude/DELEGATION.md"
    rm -f "$HOME/.claude/statusline.sh"
    rm -f "$HOME/.ssh/config.local"
    local ssh_include="Include $DOTFILES_DIR/config/ssh/config"
    if [[ -f "$latest_backup/ssh_config" ]]; then
        # A pre-install copy exists; the restore loop below puts it back
        rm -f "$HOME/.ssh/config"
    elif [[ -f "$HOME/.ssh/config" ]] && grep -qF "$ssh_include" "$HOME/.ssh/config"; then
        # No backup — surgically remove only the Include line the installer added
        local tmp
        tmp=$(mktemp)
        grep -vF "$ssh_include" "$HOME/.ssh/config" > "$tmp" || true
        mv "$tmp" "$HOME/.ssh/config"
        chmod 600 "$HOME/.ssh/config"
    fi
    rm -f "$HOME/.config/git/config"
    [[ -L "$HOME/.dotfiles" ]] && rm -f "$HOME/.dotfiles"
    rm -f "$HOME/.config/git/ignore"

    # Remove scheduled maintenance jobs
    if [[ "$OS" == "macos" ]]; then
        for name in clean-node-modules clean-worktrees clean-caches empty-trash; do
            launchctl bootout "gui/$(id -u)/com.jackmoore.maint.$name" 2>/dev/null || true
            rm -f "$HOME/Library/LaunchAgents/com.jackmoore.maint.$name.plist"
        done
    elif command -v crontab &> /dev/null; then
        crontab -l 2>/dev/null \
            | awk '/# >>> dotfiles-maint >>>/{s=1} !s; /# <<< dotfiles-maint <<</{s=0}' \
            | crontab - 2>/dev/null || true
    fi

    # Restore backed-up files
    for file in "$latest_backup"/.*; do
        [[ -f "$file" ]] || continue
        local basename
        basename=$(basename "$file")
        log_info "Restoring $basename"
        cp "$file" "$HOME/$basename"
    done

    # Restore SSH and git configs if they were backed up
    [[ -f "$latest_backup/ssh_config" ]] && { log_info "Restoring .ssh/config"; cp "$latest_backup/ssh_config" "$HOME/.ssh/config"; }
    [[ -f "$latest_backup/git_config" ]] && { log_info "Restoring .config/git/config"; cp "$latest_backup/git_config" "$HOME/.config/git/config"; }
    [[ -f "$latest_backup/git_ignore" ]] && { log_info "Restoring .config/git/ignore"; cp "$latest_backup/git_ignore" "$HOME/.config/git/ignore"; }
    [[ -f "$latest_backup/zed_settings.json" ]] && { log_info "Restoring .config/zed/settings.json"; mkdir -p "$HOME/.config/zed"; cp "$latest_backup/zed_settings.json" "$HOME/.config/zed/settings.json"; }
    [[ -f "$latest_backup/gh_config.yml" ]] && { log_info "Restoring .config/gh/config.yml"; mkdir -p "$HOME/.config/gh"; cp "$latest_backup/gh_config.yml" "$HOME/.config/gh/config.yml"; }
    [[ -d "$latest_backup/opencode" ]] && { log_info "Restoring .config/opencode"; rm -f "$HOME/.config/opencode"; cp -R "$latest_backup/opencode" "$HOME/.config/opencode"; }
    [[ -f "$latest_backup/claude_settings.json.pre-merge" || -f "$latest_backup/claude_CLAUDE.md" || -f "$latest_backup/claude_TMUX.md" || -f "$latest_backup/claude_SEARCH.md" || -f "$latest_backup/claude_WEB.md" || -f "$latest_backup/claude_DELEGATION.md" || -f "$latest_backup/claude_statusline.sh" ]] && mkdir -p "$HOME/.claude"
    [[ -f "$latest_backup/claude_settings.json.pre-merge" ]] && { log_info "Restoring .claude/settings.json (pre-merge)"; cp "$latest_backup/claude_settings.json.pre-merge" "$HOME/.claude/settings.json"; }
    [[ -f "$latest_backup/claude_CLAUDE.md" ]] && { log_info "Restoring .claude/CLAUDE.md"; cp "$latest_backup/claude_CLAUDE.md" "$HOME/.claude/CLAUDE.md"; }
    [[ -f "$latest_backup/claude_TMUX.md" ]] && { log_info "Restoring .claude/TMUX.md"; cp "$latest_backup/claude_TMUX.md" "$HOME/.claude/TMUX.md"; }
    [[ -f "$latest_backup/claude_SEARCH.md" ]] && { log_info "Restoring .claude/SEARCH.md"; cp "$latest_backup/claude_SEARCH.md" "$HOME/.claude/SEARCH.md"; }
    [[ -f "$latest_backup/claude_WEB.md" ]] && { log_info "Restoring .claude/WEB.md"; cp "$latest_backup/claude_WEB.md" "$HOME/.claude/WEB.md"; }
    [[ -f "$latest_backup/claude_DELEGATION.md" ]] && { log_info "Restoring .claude/DELEGATION.md"; cp "$latest_backup/claude_DELEGATION.md" "$HOME/.claude/DELEGATION.md"; }

    log_success "Rollback complete from $latest_backup"
    log_info "Please restart your terminal"
}

# Main installation
main() {
    log_info "Starting dotfiles installation..."
    
    setup_dotfiles_link
    install_homebrew
    install_packages
    setup_zsh_plugins
    create_symlinks
    setup_tmux
    setup_cw
    setup_claude
    setup_playwright_cli
    setup_zed
    setup_gh
    setup_crawl4ai
    setup_maintenance

    if [[ "$OS" == "macos" ]]; then
        setup_colima
    fi
    
    log_success "Dotfiles installation complete!"
    log_info "Please restart your terminal or run: source ~/.zshrc"
    log_info "Backup files are in: $BACKUP_DIR"
    log_warning "Action required: set user.name, user.email, and user.signingKey in ~/.config/git/config.local before making commits (gpgSign is enabled by default)"
}

# Run rollback or main
if [[ "$ROLLBACK" == true ]]; then
    rollback
else
    main
fi
