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
        log_info "[DRY RUN] Would link starship.toml, mise/config.toml, and ghostty/config"
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

    # Restore backed-up files
    for file in "$latest_backup"/.*; do
        [[ -f "$file" ]] || continue
        local basename
        basename=$(basename "$file")
        log_info "Restoring $basename"
        cp "$file" "$HOME/$basename"
    done

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
    
    if [[ "$OS" == "macos" ]]; then
        setup_services
        setup_colima
    fi
    
    log_success "Dotfiles installation complete!"
    log_info "Please restart your terminal or run: source ~/.zshrc"
    log_info "Backup files are in: $BACKUP_DIR"
}

# Run rollback or main
if [[ "$ROLLBACK" == true ]]; then
    rollback
else
    main
fi
