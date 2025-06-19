# .zshenv - Environment Setup
# This file is ALWAYS sourced by zsh, regardless of shell type
# Keep this file lightweight - only essential environment variables

# XDG Base Directory Specification
# Define these early as other configs depend on them
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Ensure XDG directories exist
[[ -d "$XDG_CONFIG_HOME" ]] || mkdir -p "$XDG_CONFIG_HOME"
[[ -d "$XDG_DATA_HOME" ]] || mkdir -p "$XDG_DATA_HOME"
[[ -d "$XDG_CACHE_HOME" ]] || mkdir -p "$XDG_CACHE_HOME"
[[ -d "$XDG_STATE_HOME" ]] || mkdir -p "$XDG_STATE_HOME"

# Language and locale (set early)
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Core editor settings
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-nvim}"

# Essential PATH setup
# Build PATH efficiently without duplicates
typeset -U path PATH
path=(
    # Homebrew paths (macOS and Linux)
    /opt/homebrew/bin
    /opt/homebrew/sbin
    /usr/local/bin
    /usr/local/sbin
    /home/linuxbrew/.linuxbrew/bin
    /home/linuxbrew/.linuxbrew/sbin
    
    # User paths
    "$HOME/.local/bin"
    "$HOME/bin"
    
    # System paths
    /usr/bin
    /bin
    /usr/sbin
    /sbin
    
    # Keep existing PATH
    $path
)

# Remove non-existent paths for cleaner PATH
path=($^path(N-/))

# Essential environment variables only
export PAGER="${PAGER:-less}"
export LESS="-R -M -i -j5"

# History file location (XDG compliant)
export HISTFILE="$XDG_DATA_HOME/zsh/history"

# Zsh configuration location
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

# Development environment flag
export DEVELOPMENT_ENVIRONMENT="${DEVELOPMENT_ENVIRONMENT:-local}"

# Skip global compinit for faster startup
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ANALYTICS=1

# Mise (runtime manager) - minimal setup
export MISE_DATA_DIR="$XDG_DATA_HOME/mise"
export MISE_CONFIG_DIR="$XDG_CONFIG_HOME/mise"
export MISE_CACHE_DIR="$XDG_CACHE_HOME/mise"

# GPG TTY for signing
export GPG_TTY="$(tty)"

# Dotfiles directory
export DOTFILES="$HOME/.dotfiles"
