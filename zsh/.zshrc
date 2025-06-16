# ~/.zshrc - High-performance zsh configuration

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.

# ============================================================================
# PERFORMANCE OPTIMIZATION
# ============================================================================

# Skip global compinit for faster startup
skip_global_compinit=1

# Disable checking of new mail
unset MAILCHECK

# ============================================================================
# ZSH OPTIONS
# ============================================================================

# History
setopt HIST_IGNORE_DUPS        # Don't record an entry that was just recorded again
setopt HIST_IGNORE_ALL_DUPS    # Delete old recorded entry if new entry is a duplicate
setopt HIST_FIND_NO_DUPS       # Do not display a line previously found
setopt HIST_IGNORE_SPACE      # Don't record an entry starting with a space
setopt HIST_SAVE_NO_DUPS      # Don't write duplicate entries in the history file
setopt HIST_REDUCE_BLANKS     # Remove superfluous blanks before recording entry
setopt HIST_VERIFY            # Don't execute immediately upon history expansion
setopt EXTENDED_HISTORY       # Write the history file in the ":start:elapsed;command" format
setopt INC_APPEND_HISTORY     # Write to the history file immediately, not when the shell exits
setopt SHARE_HISTORY          # Share history between all sessions

# Directory navigation
setopt AUTO_CD                # Auto cd to a directory without typing cd
setopt AUTO_PUSHD            # Push the old directory onto the stack on cd
setopt PUSHD_IGNORE_DUPS     # Do not store duplicates in the stack
setopt PUSHD_SILENT          # Do not print the directory stack after pushd or popd

# Completion
setopt COMPLETE_IN_WORD      # Complete from both ends of a word
setopt ALWAYS_TO_END         # Move cursor to the end of a completed word
setopt PATH_DIRS             # Perform path search even on command names with slashes
setopt AUTO_MENU             # Show completion menu on a successive tab press
setopt AUTO_LIST             # Automatically list choices on ambiguous completion
setopt AUTO_PARAM_SLASH      # If completed parameter is a directory, add a trailing slash
unsetopt MENU_COMPLETE       # Do not autoselect the first completion entry
unsetopt FLOW_CONTROL        # Disable start/stop characters in shell editor

# Correction
setopt CORRECT               # Auto correct commands
unsetopt CORRECT_ALL         # Don't auto correct arguments

# ============================================================================
# HISTORY CONFIGURATION
# ============================================================================

HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=10000

# ============================================================================
# COMPLETION SYSTEM
# ============================================================================

# Initialize completion system
autoload -Uz compinit

# Only regenerate compdump once per day for performance
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# Load additional completions
fpath=(~/.config/zsh/plugins/zsh-completions/src $fpath)

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ============================================================================
# KEY BINDINGS
# ============================================================================

# Use emacs key bindings
bindkey -e

# History search
bindkey '^R' history-incremental-search-backward
bindkey '^S' history-incremental-search-forward

# Move word by word
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================

# Editor
export EDITOR='vim'
export VISUAL='vim'

# Language
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Less
export LESS='-R'
export LESSOPEN='|~/.lessfilter %s'

# ============================================================================
# PATH CONFIGURATION
# ============================================================================

# Add common paths
path=(
    /usr/local/bin
    /usr/local/sbin
    /usr/bin
    /usr/sbin
    /bin
    /sbin
    ~/.local/bin
    $path
)

# macOS specific paths
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Homebrew
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# Remove duplicates
typeset -U path

# ============================================================================
# DEVELOPMENT ENVIRONMENT SETUP
# ============================================================================

# Node.js - nvm (lazy loading for performance)
export NVM_DIR="$HOME/.nvm"
nvm() {
    unset -f nvm
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm "$@"
}

# Ruby - rbenv (lazy loading)
if [[ -d ~/.rbenv ]]; then
    export PATH="$HOME/.rbenv/bin:$PATH"
    rbenv() {
        unset -f rbenv
        eval "$(command rbenv init -)"
        rbenv "$@"
    }
fi

# Python - pyenv (lazy loading)
if [[ -d ~/.pyenv ]]; then
    export PATH="$HOME/.pyenv/bin:$PATH"
    pyenv() {
        unset -f pyenv
        eval "$(command pyenv init -)"
        pyenv "$@"
    }
fi

# Go
if [[ -d /usr/local/go ]]; then
    export PATH="/usr/local/go/bin:$PATH"
fi
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

# ============================================================================
# PLUGINS
# ============================================================================

# Load plugins manually for performance
PLUGIN_DIR="$HOME/.config/zsh/plugins"

# Syntax highlighting (load last)
if [[ -f "$PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "$PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# Autosuggestions
if [[ -f "$PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
fi

# ============================================================================
# EXTERNAL TOOLS
# ============================================================================

# fzf
if command -v fzf >/dev/null 2>&1; then
    # Key bindings
    if [[ -f ~/.fzf.zsh ]]; then
        source ~/.fzf.zsh
    elif [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
        source /usr/share/fzf/key-bindings.zsh
    fi
    
    # Configuration
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_DEFAULT_OPTS="
        --height 40% 
        --layout=reverse 
        --border 
        --inline-info
        --color=fg:#d0d0d0,bg:#121212,hl:#5f87af
        --color=fg+:#d0d0d0,bg+:#262626,hl+:#5fd7ff
        --color=info:#afaf87,prompt:#d7005f,pointer:#af5fff
        --color=marker:#87ff00,spinner:#af5fff,header:#87afaf"
fi

# Starship prompt
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# ============================================================================
# LOAD ADDITIONAL CONFIGURATIONS
# ============================================================================

# Load aliases
[[ -f ~/.config/zsh/aliases.zsh ]] && source ~/.config/zsh/aliases.zsh

# Load functions
[[ -f ~/.config/zsh/functions.zsh ]] && source ~/.config/zsh/functions.zsh

# Load local configuration (not tracked by git)
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# ============================================================================
# FINAL SETUP
# ============================================================================

# Enable command substitution in prompts
setopt PROMPT_SUBST

# Load any additional completion scripts
if [[ -d ~/.config/zsh/completions ]]; then
    fpath=(~/.config/zsh/completions $fpath)
fi

# Rehash commands automatically
zstyle ':completion:*' rehash true