#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

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
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

log_info "Detected OS: $OS"
log_info "Dotfiles directory: $DOTFILES_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup existing dotfiles
backup_file() {
    local file="$1"
    if [[ -f "$HOME/$file" ]] || [[ -L "$HOME/$file" ]]; then
        log_info "Backing up existing $file"
        mv "$HOME/$file" "$BACKUP_DIR/"
    fi
}

# Install Homebrew
install_homebrew() {
    if ! command -v brew &> /dev/null; then
        log_info "Installing Homebrew..."
        if [[ "$OS" == "macos" ]]; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            # Linux/WSL
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
            # Add Homebrew to PATH for Linux
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
        brew bundle --file="$DOTFILES_DIR/Brewfile"
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
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"
    fi
    
    if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions.git "$plugins_dir/zsh-autosuggestions"
    fi
    
    if [[ ! -d "$plugins_dir/zsh-completions" ]]; then
        git clone https://github.com/zsh-users/zsh-completions.git "$plugins_dir/zsh-completions"
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

    echo 'export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:=${HOME}/.config}' >> "$HOME/.zshenv"
    echo 'export ZDOTDIR=${ZDOTDIR:=${XDG_CONFIG_HOME}/zsh}' >> "$HOME/.zshenv"
    echo 'source $ZDOTDIR/.zshenv' >> "$HOME/.zshenv"

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
    
    log_success "Symlinks created"
}

# Setup services
setup_services() {
    log_info "Setting up services..."
    if [[ -f "$DOTFILES_DIR/scripts/setup-services.sh" ]]; then
        zsh "$DOTFILES_DIR/scripts/setup-services.zsh"
    fi
}

# Setup Colima
setup_colima() {
    log_info "Setting up Colima..."
    if [[ -f "$DOTFILES_DIR/scripts/setup-colima.sh" ]]; then
        zsh "$DOTFILES_DIR/scripts/setup-colima.zsh"
    fi
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

# Run main function
main "$@"
