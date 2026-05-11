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

# Backup existing dotfiles
backup_file() {
    local file="$1"
    if [[ -f "$HOME/$file" ]] || [[ -L "$HOME/$file" ]]; then
        log_info "Backing up existing $file"
        run mv "$HOME/$file" "$BACKUP_DIR/"
    fi
}

# Link a Claude Code config file with idempotency and backup.
# Args: <dotfiles-source-path> <target-path> <backup-filename>
link_claude_file() {
    local src="$1"
    local dst="$2"
    local backup_name="$3"

    if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
        log_info "Already linked: $dst"
        return
    fi

    if [[ -f "$dst" || -L "$dst" ]]; then
        log_info "Backing up existing $(basename "$dst")"
        run mv "$dst" "$BACKUP_DIR/$backup_name"
    fi

    run ln -sf "$src" "$dst"
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

    local tmux_dir="$HOME/.config/tmux"
    run mkdir -p "$tmux_dir/plugins"

    run ln -sf "$DOTFILES_DIR/config/tmux/tmux.conf" "$tmux_dir/tmux.conf"

    # Bootstrap TPM. Plugins themselves install on first `prefix + I`.
    if [[ ! -d "$tmux_dir/plugins/tpm" ]]; then
        run git clone --depth=1 https://github.com/tmux-plugins/tpm "$tmux_dir/plugins/tpm"
        log_info "TPM installed. Open tmux, then press prefix + I to install plugins"
    fi

    log_success "tmux config setup complete"
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
    link_claude_file "$DOTFILES_DIR/config/claude/CLAUDE.md" "$claude_dir/CLAUDE.md" "claude_CLAUDE.md"
    link_claude_file "$DOTFILES_DIR/config/claude/TMUX.md" "$claude_dir/TMUX.md" "claude_TMUX.md"
    link_claude_file "$DOTFILES_DIR/config/claude/SEARCH.md" "$claude_dir/SEARCH.md" "claude_SEARCH.md"
    link_claude_file "$DOTFILES_DIR/config/claude/WEB.md" "$claude_dir/WEB.md" "claude_WEB.md"

    log_success "Claude Code config setup complete"
}

# Create symlinks
create_symlinks() {
    log_info "Creating symlinks..."
    
    # Backup and link zsh files
    backup_file ".zshenv"
    backup_file ".zprofile"
    backup_file ".zshrc"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY RUN] Would write $HOME/.zshenv"
        log_info "[DRY RUN] Would create symlinks in $HOME/.config/zsh/"
        log_info "[DRY RUN] Would link starship.toml, mise/config.toml, mise/default-npm-packages, mise/default-python-packages, ghostty/config, and git/config; prepend Include to ~/.ssh/config"
        log_info "[DRY RUN] Would write $HOME/.ssh/config.local with platform IdentityAgent"
    else
        cat > "$HOME/.zshenv" << 'ZSHENV'
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:=${HOME}/.config}
export ZDOTDIR=${ZDOTDIR:=${XDG_CONFIG_HOME}/zsh}
source $ZDOTDIR/.zshenv
ZSHENV

        # Create config directories and symlinks
        mkdir -p "$HOME/.config/zsh"

        ln -sf "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.config/zsh/.zshenv"
        ln -sf "$DOTFILES_DIR/zsh/.zprofile" "$HOME/.config/zsh/.zprofile"
        ln -sf "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.config/zsh/.zshrc"

        # Starship config
        ln -sf "$DOTFILES_DIR/config/starship.toml" "$HOME/.config/starship.toml"

        # Mise config
        mkdir -p "$HOME/.config/mise"
        ln -sf "$DOTFILES_DIR/config/mise/config.toml" "$HOME/.config/mise/config.toml"
        ln -sf "$DOTFILES_DIR/config/mise/default-npm-packages" "$HOME/.config/mise/default-npm-packages"
        ln -sf "$DOTFILES_DIR/config/mise/default-python-packages" "$HOME/.config/mise/default-python-packages"

        # Ghostty config
        mkdir -p "$HOME/.config/ghostty"
        ln -sf "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"

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
        mkdir -p "$HOME/.config/git"
        [[ -f "$HOME/.config/git/config" && ! -L "$HOME/.config/git/config" ]] && run mv "$HOME/.config/git/config" "$BACKUP_DIR/git_config"
        ln -sf "$DOTFILES_DIR/config/git/config" "$HOME/.config/git/config"
        ln -sf "$DOTFILES_DIR/config/git/ignore" "$HOME/.config/git/ignore"
        # Ensure local overrides file exists (user.name, user.email, user.signingKey)
        [[ -f "$HOME/.config/git/config.local" ]] || touch "$HOME/.config/git/config.local"
    fi
    
    log_success "Symlinks created"
}

# Setup Zed config
setup_zed() {
    log_info "Setting up Zed config..."
    run mkdir -p "$HOME/.config/zed"
    if [[ -f "$HOME/.config/zed/settings.json" && ! -L "$HOME/.config/zed/settings.json" ]]; then
        run mv "$HOME/.config/zed/settings.json" "$BACKUP_DIR/zed_settings.json"
    fi
    run ln -sf "$DOTFILES_DIR/config/zed/settings.json" "$HOME/.config/zed/settings.json"
    log_success "Zed config setup complete"
}

# Setup gh (GitHub CLI) config
setup_gh() {
    log_info "Setting up gh config..."
    run mkdir -p "$HOME/.config/gh"
    if [[ -f "$HOME/.config/gh/config.yml" && ! -L "$HOME/.config/gh/config.yml" ]]; then
        run mv "$HOME/.config/gh/config.yml" "$BACKUP_DIR/gh_config.yml"
    fi
    run ln -sf "$DOTFILES_DIR/config/gh/config.yml" "$HOME/.config/gh/config.yml"
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

# Rollback from most recent backup
rollback() {
    local latest_backup
    latest_backup=$(ls -dt "$HOME"/.dotfiles_backup_* 2>/dev/null | head -1)

    if [[ -z "$latest_backup" ]]; then
        log_error "No backup directory found"
        exit 1
    fi

    log_info "Rolling back from: $latest_backup"

    # Remove symlinks
    rm -f "$HOME/.config/zsh/.zshenv" "$HOME/.config/zsh/.zprofile" "$HOME/.config/zsh/.zshrc"
    rm -f "$HOME/.config/starship.toml" "$HOME/.config/mise/config.toml" "$HOME/.config/mise/default-npm-packages" "$HOME/.config/mise/default-python-packages"
    rm -f "$HOME/.config/ghostty/config"
    rm -f "$HOME/.config/tmux/tmux.conf"
    rm -rf "$HOME/.config/tmux/plugins/tpm"
    rm -f "$HOME/.config/zed/settings.json"
    rm -f "$HOME/.config/gh/config.yml"
    # settings.json is a real merged file, not a symlink — leave it in place and let the pre-merge restore (below) decide
    rm -f "$HOME/.claude/CLAUDE.md" "$HOME/.claude/TMUX.md" "$HOME/.claude/SEARCH.md" "$HOME/.claude/WEB.md"
    rm -f "$HOME/.ssh/config" "$HOME/.ssh/config.local"
    rm -f "$HOME/.config/git/config"

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
    [[ -f "$latest_backup/zed_settings.json" ]] && { log_info "Restoring .config/zed/settings.json"; mkdir -p "$HOME/.config/zed"; cp "$latest_backup/zed_settings.json" "$HOME/.config/zed/settings.json"; }
    [[ -f "$latest_backup/gh_config.yml" ]] && { log_info "Restoring .config/gh/config.yml"; mkdir -p "$HOME/.config/gh"; cp "$latest_backup/gh_config.yml" "$HOME/.config/gh/config.yml"; }
    [[ -f "$latest_backup/claude_settings.json.pre-merge" || -f "$latest_backup/claude_CLAUDE.md" || -f "$latest_backup/claude_TMUX.md" || -f "$latest_backup/claude_SEARCH.md" || -f "$latest_backup/claude_WEB.md" ]] && mkdir -p "$HOME/.claude"
    [[ -f "$latest_backup/claude_settings.json.pre-merge" ]] && { log_info "Restoring .claude/settings.json (pre-merge)"; cp "$latest_backup/claude_settings.json.pre-merge" "$HOME/.claude/settings.json"; }
    [[ -f "$latest_backup/claude_CLAUDE.md" ]] && { log_info "Restoring .claude/CLAUDE.md"; cp "$latest_backup/claude_CLAUDE.md" "$HOME/.claude/CLAUDE.md"; }
    [[ -f "$latest_backup/claude_TMUX.md" ]] && { log_info "Restoring .claude/TMUX.md"; cp "$latest_backup/claude_TMUX.md" "$HOME/.claude/TMUX.md"; }
    [[ -f "$latest_backup/claude_SEARCH.md" ]] && { log_info "Restoring .claude/SEARCH.md"; cp "$latest_backup/claude_SEARCH.md" "$HOME/.claude/SEARCH.md"; }
    [[ -f "$latest_backup/claude_WEB.md" ]] && { log_info "Restoring .claude/WEB.md"; cp "$latest_backup/claude_WEB.md" "$HOME/.claude/WEB.md"; }

    log_success "Rollback complete from $latest_backup"
    log_info "Please restart your terminal"
}

# Main installation
main() {
    log_info "Starting dotfiles installation..."
    
    install_homebrew
    install_packages
    setup_zsh_plugins
    create_symlinks
    setup_tmux
    setup_claude
    setup_playwright_cli
    setup_zed
    setup_gh
    setup_crawl4ai

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
