#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    else
        print_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    print_success "Detected OS: $OS"
}

# Install package manager
install_package_manager() {
    if [[ "$OS" == "macos" ]]; then
        if ! command -v brew >/dev/null 2>&1; then
            print_status "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            print_success "Homebrew installed"
        else
            print_success "Homebrew already installed"
        fi
    elif [[ "$OS" == "linux" ]]; then
        # Update package lists
        if command -v apt >/dev/null 2>&1; then
            print_status "Updating apt packages..."
            sudo apt update
        elif command -v yum >/dev/null 2>&1; then
            print_status "Updating yum packages..."
            sudo yum update -y
        fi
    fi
}

# Install packages
install_packages() {
    if [[ "$OS" == "macos" ]]; then
        print_status "Installing packages via Homebrew..."
        brew bundle --file="$DOTFILES_DIR/homebrew/Brewfile"
        print_success "Packages installed"
    elif [[ "$OS" == "linux" ]]; then
        print_status "Installing essential packages..."
        if command -v apt >/dev/null 2>&1; then
            sudo apt install -y curl git zsh build-essential
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y curl git zsh gcc gcc-c++ make
        fi
        
        # Install individual tools for Linux
        install_linux_tools
    fi
}

install_linux_tools() {
    # Starship
    if ! command -v starship >/dev/null 2>&1; then
        print_status "Installing Starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi
    
    # fzf
    if ! command -v fzf >/dev/null 2>&1; then
        print_status "Installing fzf..."
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ~/.fzf/install --all
    fi
    
    # ripgrep
    if ! command -v rg >/dev/null 2>&1; then
        print_status "Installing ripgrep..."
        if command -v apt >/dev/null 2>&1; then
            sudo apt install -y ripgrep
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y ripgrep
        fi
    fi
}

# Create necessary directories
create_directories() {
    print_status "Creating directories..."
    mkdir -p ~/.config/zsh/plugins
    mkdir -p ~/.config
    print_success "Directories created"
}

# Install zsh plugins
install_zsh_plugins() {
    print_status "Installing zsh plugins..."
    
    PLUGIN_DIR="$HOME/.config/zsh/plugins"
    
    # zsh-syntax-highlighting
    if [[ ! -d "$PLUGIN_DIR/zsh-syntax-highlighting" ]]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$PLUGIN_DIR/zsh-syntax-highlighting"
    fi
    
    # zsh-autosuggestions
    if [[ ! -d "$PLUGIN_DIR/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions.git "$PLUGIN_DIR/zsh-autosuggestions"
    fi
    
    # zsh-completions
    if [[ ! -d "$PLUGIN_DIR/zsh-completions" ]]; then
        git clone https://github.com/zsh-users/zsh-completions.git "$PLUGIN_DIR/zsh-completions"
    fi
    
    print_success "Zsh plugins installed"
}

# Link configuration files
link_configs() {
    print_status "Linking configuration files..."
    
    # Backup existing files
    backup_if_exists ~/.zshrc
    backup_if_exists ~/.zshenv
    backup_if_exists ~/.gitconfig
    backup_if_exists ~/.config/starship.toml
    
    # Create symlinks
    ln -sf "$DOTFILES_DIR/zsh/.zshrc" ~/.zshrc
    ln -sf "$DOTFILES_DIR/zsh/.zshenv" ~/.zshenv
    ln -sf "$DOTFILES_DIR/config/.gitconfig" ~/.gitconfig
    ln -sf "$DOTFILES_DIR/config/starship.toml" ~/.config/starship.toml
    
    print_success "Configuration files linked"
}

backup_if_exists() {
    if [[ -f "$1" && ! -L "$1" ]]; then
        print_warning "Backing up existing $1 to $1.backup"
        mv "$1" "$1.backup"
    fi
}

# Install development environments
install_dev_environments() {
    print_status "Setting up development environments..."
    
    # Node.js via nvm
    if [[ ! -d "$HOME/.nvm" ]]; then
        print_status "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        
        # Source nvm and install latest LTS Node
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install --lts
        nvm use --lts
    fi
    
    # Ruby via rbenv (if not on macOS where it's handled by Homebrew)
    if [[ "$OS" == "linux" && ! -d "$HOME/.rbenv" ]]; then
        print_status "Installing rbenv..."
        git clone https://github.com/rbenv/rbenv.git ~/.rbenv
        git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    fi
    
    # Python via pyenv (if not on macOS where it's handled by Homebrew)
    if [[ "$OS" == "linux" && ! -d "$HOME/.pyenv" ]]; then
        print_status "Installing pyenv..."
        git clone https://github.com/pyenv/pyenv.git ~/.pyenv
    fi
    
    print_success "Development environments ready"
}

# Change default shell to zsh
change_shell() {
    if [[ "$SHELL" != */zsh ]]; then
        print_status "Changing default shell to zsh..."
        if command -v zsh >/dev/null 2>&1; then
            chsh -s "$(which zsh)"
            print_success "Default shell changed to zsh"
            print_warning "Please restart your terminal or run 'exec zsh' to start using the new configuration"
        else
            print_error "zsh not found in PATH"
        fi
    else
        print_success "zsh is already the default shell"
    fi
}

# Main installation function
main() {
    print_status "Starting dotfiles installation..."
    
    detect_os
    install_package_manager
    install_packages
    create_directories
    install_zsh_plugins
    link_configs
    install_dev_environments
    change_shell
    
    print_success "Dotfiles installation complete!"
    echo
    print_status "Next steps:"
    echo "  1. Restart your terminal or run: exec zsh"
    echo "  2. Install Node.js LTS: nvm install --lts && nvm use --lts"
    echo "  3. Install latest Ruby: rbenv install 3.1.0 && rbenv global 3.1.0"
    echo "  4. Install latest Python: pyenv install 3.11.0 && pyenv global 3.11.0"
    echo
    print_status "Enjoy your new development environment! 🚀"
}

# Run main function
main "$@"