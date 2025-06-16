# ~/.zshenv - Environment variables for zsh
# This file is always sourced, so keep it fast and minimal

# ============================================================================
# XDG BASE DIRECTORIES
# ============================================================================

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

# ============================================================================
# DEFAULT APPLICATIONS
# ============================================================================

export EDITOR='vim'
export VISUAL='vim'
export PAGER='less'
export BROWSER='open'

# ============================================================================
# LANGUAGE & LOCALE
# ============================================================================

export LANG='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

# ============================================================================
# DEVELOPMENT TOOLS
# ============================================================================

# Node.js
export NVM_DIR="$HOME/.nvm"
export NPM_CONFIG_PREFIX="$HOME/.npm-global"

# Ruby
export RBENV_ROOT="$HOME/.rbenv"

# Python
export PYENV_ROOT="$HOME/.pyenv"
export PYTHONDONTWRITEBYTECODE=1

# Go
export GOPATH="$HOME/go"
export GO111MODULE=on

# Rust
export CARGO_HOME="$HOME/.cargo"
export RUSTUP_HOME="$HOME/.rustup"

# Java (if using SDKMAN)
export SDKMAN_DIR="$HOME/.sdkman"

# ============================================================================
# TOOL CONFIGURATIONS
# ============================================================================

# Less
export LESS='-F -g -i -M -R -S -w -X -z-4'
export LESSHISTFILE="$XDG_CACHE_HOME/less/history"

# Grep
export GREP_OPTIONS='--color=auto'

# FZF
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# GPG
export GPG_TTY=$(tty)

# SSH
export SSH_KEY_PATH="$HOME/.ssh/id_rsa"

# ============================================================================
# PERFORMANCE & SECURITY
# ============================================================================

# History
export HISTFILE="$XDG_STATE_HOME/zsh/history"
export HISTSIZE=50000
export SAVEHIST=10000

# Disable analytics for various tools
export HOMEBREW_NO_ANALYTICS=1
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export GATSBY_TELEMETRY_DISABLED=1
export NEXT_TELEMETRY_DISABLED=1

# ============================================================================
# PATH MODIFICATIONS
# ============================================================================

# Function to safely add to PATH
add_to_path() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

# Add user directories
add_to_path "$HOME/.local/bin"
add_to_path "$HOME/bin"

# Add development tool directories
add_to_path "$CARGO_HOME/bin"
add_to_path "$GOPATH/bin"
add_to_path "$NPM_CONFIG_PREFIX/bin"

# macOS specific
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Homebrew paths
    if [[ -d /opt/homebrew ]]; then
        add_to_path "/opt/homebrew/bin"
        add_to_path "/opt/homebrew/sbin"
        export HOMEBREW_PREFIX="/opt/homebrew"
    elif [[ -d /usr/local/Homebrew ]]; then
        add_to_path "/usr/local/bin"
        add_to_path "/usr/local/sbin"  
        export HOMEBREW_PREFIX="/usr/local"
    fi
    
    # macOS system paths
    add_to_path "/usr/local/bin"
    add_to_path "/System/Cryptexes/App/usr/bin"
fi

export PATH

# ============================================================================
# CLEANUP
# ============================================================================

# Remove function after use
unset -f add_to_path