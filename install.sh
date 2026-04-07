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

# Setup Claude Code config
setup_claude() {
    log_info "Setting up Claude Code config..."

    local claude_dir="$HOME/.claude"
    run mkdir -p "$claude_dir"

    link_claude_file "$DOTFILES_DIR/config/claude/settings.json" "$claude_dir/settings.json" "claude_settings.json"
    link_claude_file "$DOTFILES_DIR/config/claude/CLAUDE.md" "$claude_dir/CLAUDE.md" "claude_CLAUDE.md"

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
        log_info "[DRY RUN] Would link starship.toml, mise/config.toml, ghostty/config, ssh/config, and git/config"
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

        # Ghostty config
        mkdir -p "$HOME/.config/ghostty"
        ln -sf "$DOTFILES_DIR/config/ghostty/config" "$HOME/.config/ghostty/config"

        # SSH config
        mkdir -p "$HOME/.ssh" "$HOME/.ssh/control"
        chmod 700 "$HOME/.ssh" "$HOME/.ssh/control"
        [[ -f "$HOME/.ssh/config" && ! -L "$HOME/.ssh/config" ]] && run mv "$HOME/.ssh/config" "$BACKUP_DIR/ssh_config"
        ln -sf "$DOTFILES_DIR/config/ssh/config" "$HOME/.ssh/config"

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

# Setup services
setup_services() {
    log_info "Setting up services..."
    if [[ -f "$DOTFILES_DIR/scripts/setup-services.zsh" ]]; then
        run zsh "$DOTFILES_DIR/scripts/setup-services.zsh"
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
    rm -f "$HOME/.config/starship.toml" "$HOME/.config/mise/config.toml"
    rm -f "$HOME/.config/ghostty/config"
    rm -f "$HOME/.claude/settings.json" "$HOME/.claude/CLAUDE.md"
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
    [[ -f "$latest_backup/claude_settings.json" || -f "$latest_backup/claude_CLAUDE.md" ]] && mkdir -p "$HOME/.claude"
    [[ -f "$latest_backup/claude_settings.json" ]] && { log_info "Restoring .claude/settings.json"; cp "$latest_backup/claude_settings.json" "$HOME/.claude/settings.json"; }
    [[ -f "$latest_backup/claude_CLAUDE.md" ]] && { log_info "Restoring .claude/CLAUDE.md"; cp "$latest_backup/claude_CLAUDE.md" "$HOME/.claude/CLAUDE.md"; }

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
    setup_claude

    if [[ "$OS" == "macos" ]]; then
        setup_services
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
