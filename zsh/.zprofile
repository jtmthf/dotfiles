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

# Mise initialization (shims for non-interactive sessions)
if command -v mise &> /dev/null; then
    eval "$(mise activate zsh --shims)"
fi

# macOS specific login setup
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Add macOS-specific PATH elements
    path=(
        "/System/Cryptexes/App/usr/bin"
        $path
    )
    
    # SSH agent: we rely on 1Password IdentityAgent (configured in ssh/config),
    # so no need to start a separate ssh-agent or load Keychain keys.
    # SSH_AUTH_SOCK will be set by 1Password via ~/.ssh/config.local.
fi

# Linux/WSL specific login setup
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Start SSH agent if not running and 1Password's agent.sock is unavailable
    if [[ -z "$SSH_AUTH_SOCK" ]] && [[ ! -S "$HOME/.1password/agent.sock" ]]; then
        if ! ssh-add -l &>/dev/null 2>&1; then
            eval "$(ssh-agent -s)" > /dev/null 2>&1
        fi
    fi
    
    # WSL specific setup
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        # Fix for WSL display
        export DISPLAY="${DISPLAY:-:0}"
    fi
fi

# Development tools initialization (login only)
# These are expensive operations that should only run once

# JAVA_HOME setup (if java is installed via mise)
# Guard with `mise which` to avoid a subshell when java is not in mise
if command -v mise &> /dev/null && mise which java &>/dev/null; then
    export JAVA_HOME="$(mise where java)"
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

# Python/Ruby PATHs are managed by mise activate

# Clean up PATH again after all additions
path=($^path(N-/))
typeset -U path PATH

# Create essential directories
mkdir -p "$XDG_DATA_HOME/zsh"
mkdir -p "$XDG_STATE_HOME/zsh"
mkdir -p "$HOME/.local/bin"

# One-time setup checks (create marker files to avoid repeated setup)
SETUP_MARKER="$XDG_STATE_HOME/zsh/setup_complete"

if [[ ! -f "$SETUP_MARKER" ]]; then
    # First-time setup tasks
    
    # Generate SSH key if none exists
    if [[ ! -f "$HOME/.ssh/id_ed25519" ]] && [[ ! -f "$HOME/.ssh/id_rsa" ]]; then
        echo "No SSH key found. Consider generating one with:"
        echo "  ssh-keygen -t ed25519 -C 'your.email@example.com'"
    fi
    
    # Git config reminder (only on first login)
    if ! git config --global user.name &> /dev/null; then
        echo "Git user not configured. Consider running:"
        echo "  git config --global user.name 'Your Name'"
        echo "  git config --global user.email 'your.email@example.com'"
    fi
    
    # Create useful directories
    mkdir -p "$HOME/Development"
    mkdir -p "$HOME/Projects"
    
    # Mark setup as complete
    mkdir -p "$(dirname "$SETUP_MARKER")"
    touch "$SETUP_MARKER"
fi


