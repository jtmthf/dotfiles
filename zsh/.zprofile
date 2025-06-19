# .zprofile - Login Shell Setup
# This file is sourced for LOGIN shells (when you first log in)
# Use for expensive operations that should only run once per session

# Homebrew initialization (expensive, so only run once)
if [[ -z "$HOMEBREW_PREFIX" ]]; then
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    elif [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

# Mise initialization (for login shells)
if command -v mise &> /dev/null && [[ -z "$MISE_SHELL" ]]; then
    eval "$(mise activate zsh)"
fi

# macOS specific login setup
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Add macOS-specific PATH elements
    path=(
        "/Applications/Docker.app/Contents/Resources/bin"
        "/System/Cryptexes/App/usr/bin"
        $path
    )
    
    # macOS Keychain SSH agent
    if [[ -z "$SSH_AUTH_SOCK" ]]; then
        eval "$(ssh-agent -s)" > /dev/null 2>&1
    fi
    
    # Load SSH keys from keychain
    ssh-add --apple-load-keychain > /dev/null 2>&1
fi

# Linux/WSL specific login setup
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Start SSH agent if not running
    if [[ -z "$SSH_AUTH_SOCK" ]]; then
        eval "$(ssh-agent -s)" > /dev/null 2>&1
    fi
    
    # WSL specific setup
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        # WSL-specific configurations
        export BROWSER="wslview"
        
        # Fix for WSL display
        export DISPLAY="${DISPLAY:-:0}"
        
        # Windows PATH integration (optional)
        # export WSLPATH="$(wslpath -w /)"
    fi
fi

# Development tools initialization (login only)
# These are expensive operations that should only run once

# Docker Desktop integration (macOS)
if [[ "$OSTYPE" == "darwin"* ]] && [[ -d "/Applications/Docker.app" ]]; then
    path=("/Applications/Docker.app/Contents/Resources/bin" $path)
fi

# JAVA_HOME setup (if java is installed via mise)
if command -v mise &> /dev/null; then
    export JAVA_HOME="$(mise where java 2>/dev/null || echo "")"
fi

# Go workspace setup
if command -v go &> /dev/null; then
    export GOPATH="${GOPATH:-$HOME/go}"
    export GOBIN="$GOPATH/bin"
    path=("$GOBIN" $path)
fi

# Rust setup
if [[ -d "$HOME/.cargo" ]]; then
    path=("$HOME/.cargo/bin" $path)
fi

# Python user base binary directory
if command -v python3 &> /dev/null; then
    path=("$(python3 -m site --user-base)/bin" $path)
fi

# Ruby gems (if using system ruby)
if command -v ruby &> /dev/null && command -v gem &> /dev/null; then
    path=("$(ruby -r rubygems -e 'puts Gem.user_dir')/bin" $path)
fi

# Clean up PATH again after all additions
path=($^path(N-/))
typeset -U path PATH

# Create essential directories
mkdir -p "$XDG_DATA_HOME/zsh"
mkdir -p "$XDG_STATE_HOME/zsh"
mkdir -p "$HOME/.local/bin"

# Set up git configuration if not already configured
if ! git config --global user.name &> /dev/null; then
    echo "Git user not configured. Consider running:"
    echo "  git config --global user.name 'Your Name'"
    echo "  git config --global user.email 'your.email@example.com'"
fi

# One-time setup checks (create marker files to avoid repeated setup)
SETUP_MARKER="$XDG_STATE_HOME/zsh/setup_complete"

if [[ ! -f "$SETUP_MARKER" ]]; then
    # First-time setup tasks
    
    # Generate SSH key if none exists
    if [[ ! -f "$HOME/.ssh/id_ed25519" ]] && [[ ! -f "$HOME/.ssh/id_rsa" ]]; then
        echo "No SSH key found. Consider generating one with:"
        echo "  ssh-keygen -t ed25519 -C 'your.email@example.com'"
    fi
    
    # Create useful directories
    mkdir -p "$HOME/Development"
    mkdir -p "$HOME/Projects"
    
    # Mark setup as complete
    mkdir -p "$(dirname "$SETUP_MARKER")"
    touch "$SETUP_MARKER"
fi

# Performance: Cache expensive commands
if [[ ! -f "$XDG_CACHE_HOME/zsh/brew_prefix" ]] || [[ "$XDG_CACHE_HOME/zsh/brew_prefix" -ot "$(command -v brew)" ]]; then
    if command -v brew &> /dev/null; then
        mkdir -p "$XDG_CACHE_HOME/zsh"
        brew --prefix > "$XDG_CACHE_HOME/zsh/brew_prefix" 2>/dev/null
    fi
fi
