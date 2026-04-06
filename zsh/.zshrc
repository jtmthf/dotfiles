# .zshrc - Interactive Shell Configuration
# This file is sourced for INTERACTIVE shells only
# Keep startup-critical items here, defer everything else

# Performance profiling (uncomment to debug startup time)
# zmodload zsh/zprof

# Early exit if not interactive
[[ $- != *i* ]] && return

# Zsh options for better interactive experience
setopt AUTO_CD              # Auto cd to directory
setopt AUTO_PUSHD           # Push directories to stack
setopt PUSHD_IGNORE_DUPS    # Don't push duplicates
setopt PUSHD_SILENT         # Don't print directory stack
setopt GLOB_DOTS            # Include dotfiles in glob
setopt EXTENDED_GLOB        # Extended globbing
setopt HIST_VERIFY          # Show command before executing from history
setopt SHARE_HISTORY        # Share history between sessions
setopt HIST_IGNORE_DUPS     # Don't save duplicates
setopt HIST_IGNORE_ALL_DUPS # Remove older duplicates
setopt HIST_SAVE_NO_DUPS    # Don't save duplicates
setopt HIST_IGNORE_SPACE    # Don't save commands starting with space
setopt HIST_REDUCE_BLANKS   # Remove extra blanks
setopt INC_APPEND_HISTORY   # Append to history immediately
setopt CORRECT              # Auto correct commands
setopt NO_CORRECT_ALL       # Don't auto correct all arguments
setopt COMPLETE_IN_WORD     # Complete from both ends
setopt ALWAYS_TO_END        # Move cursor to end after completion
setopt AUTO_MENU            # Show completion menu on tab
setopt AUTO_LIST            # List choices on ambiguous completion
setopt AUTO_PARAM_SLASH     # Add slash after directory completion
setopt NO_MENU_COMPLETE     # Don't auto select first completion
setopt NO_FLOW_CONTROL      # Disable start/stop characters in shell editor

# History settings
HISTSIZE=50000
SAVEHIST=50000

# Completion system setup
autoload -Uz compinit

# Smart compinit: only rebuild once per day
setopt EXTENDEDGLOB
for dump in $ZDOTDIR/.zcompdump(#qN.mh+24); do
    compinit
    if [[ -s "$dump" && (! -s "$dump.zwc" || "$dump" -nt "$dump.zwc") ]]; then
        zcompile "$dump"
    fi
done
unsetopt EXTENDEDGLOB
compinit -C

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/zcompcache"
zstyle ':completion:*:*:*:*:processes' command "ps -u $USERNAME -o pid,user,comm -w -w"
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:corrections' format '%F{green}-- %d (errors: %e) --%f'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'

# Environment variables for interactive use
export PAGER="bat"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export BAT_THEME="TwoDark"
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --color=16"

# Browser setup
if [[ "$OSTYPE" == "darwin"* ]]; then
    export BROWSER="open"
elif [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    export BROWSER="wslview"
else
    export BROWSER="xdg-open"
fi

# Load dotfiles configurations
DOTFILES_DIR="$HOME/.dotfiles"

# Load custom configurations (with error handling)
load_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
    else
        echo "Warning: $config_file not found" >&2
    fi
}

# Load aliases and functions
load_config "$DOTFILES_DIR/zsh/aliases.zsh"
load_config "$DOTFILES_DIR/zsh/functions.zsh"

# Load plugins directory
PLUGINS_DIR="$DOTFILES_DIR/zsh/plugins"

# zsh-completions (load first to extend completion system)
if [[ -d "$PLUGINS_DIR/zsh-completions" ]]; then
    fpath=("$PLUGINS_DIR/zsh-completions/src" $fpath)
fi

# Mise activation (interactive sessions — full hooks for directory changes)
if command -v mise &> /dev/null; then
    eval "$(mise activate zsh)"
fi

# Initialize modern tools (lazy loading where possible)
# Starship prompt (fast, so load immediately)
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
fi

# FZF setup
if command -v fzf &> /dev/null; then
    # Load FZF key bindings and completion
    if [[ -f "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ]]; then
        source "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
    fi
    if [[ -f "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
        source "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh"
    fi
    
    # FZF configuration
    export FZF_DEFAULT_COMMAND="fd --type f --strip-cwd-prefix --hidden --follow --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fd --type d --strip-cwd-prefix --hidden --follow --exclude .git"
    export FZF_CTRL_T_OPTS="--preview 'bat --color=always --line-range :50 {}'"
    export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -50'"
fi

# Zoxide (better cd)
if command -v zoxide &> /dev/null; then
    eval "$(zoxide init --cmd cd zsh)"
fi

# Load completions configuration
load_config "$DOTFILES_DIR/zsh/completions.zsh"

# Plugin loading (load these last for best performance)
# zsh-autosuggestions
if [[ -f "$PLUGINS_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$PLUGINS_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"
    ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#586e75"
    ZSH_AUTOSUGGEST_USE_ASYNC=1
fi

# zsh-history-substring-search
if [[ -f "$(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
    source "$(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
    bindkey -e
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down  
    bindkey '^[[3~' delete-char
    bindkey '^[3;5~' delete-char
    bindkey '^R' history-incremental-search-backward
fi

# zsh-syntax-highlighting (MUST be last)
if [[ -f "$PLUGINS_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "$PLUGINS_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    
    # Customize highlighting
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
    ZSH_HIGHLIGHT_STYLES[default]=none
    ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=red,bold
    ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=cyan,bold
    ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=green,underline
    ZSH_HIGHLIGHT_STYLES[global-alias]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[precommand]=fg=green,underline
    ZSH_HIGHLIGHT_STYLES[commandseparator]=fg=blue,bold
    ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=green,underline
    ZSH_HIGHLIGHT_STYLES[path]=underline
    ZSH_HIGHLIGHT_STYLES[path_pathseparator]=
    ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]=
    ZSH_HIGHLIGHT_STYLES[globbing]=fg=blue,bold
    ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=blue,bold
    ZSH_HIGHLIGHT_STYLES[command-substitution]=none
    ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[process-substitution]=none
    ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=none
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]=fg=blue,bold
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[rc-quote]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[assign]=none
    ZSH_HIGHLIGHT_STYLES[redirection]=fg=blue,bold
    ZSH_HIGHLIGHT_STYLES[comment]=fg=black,bold
    ZSH_HIGHLIGHT_STYLES[named-fd]=none
    ZSH_HIGHLIGHT_STYLES[numeric-fd]=none
    ZSH_HIGHLIGHT_STYLES[arg0]=fg=green
fi

# Welcome message (only show occasionally)
if [[ -f "$XDG_STATE_HOME/zsh/last_welcome" ]]; then
    last_welcome=$(cat "$XDG_STATE_HOME/zsh/last_welcome" 2>/dev/null || echo "0")
    current_date=$(date +%s)
    days_since=$((($current_date - $last_welcome) / 86400))
    
    # Show welcome message once per week
    if [[ $days_since -gt 7 ]]; then
        echo "🚀 Welcome back! Type 'help-dotfiles' for available commands."
        echo "$current_date" > "$XDG_STATE_HOME/zsh/last_welcome"
    fi
else
    echo "🎉 Dotfiles loaded! Type 'help-dotfiles' for available commands."
    mkdir -p "$XDG_STATE_HOME/zsh"
    date +%s > "$XDG_STATE_HOME/zsh/last_welcome"
fi

# Performance profiling output (uncomment to debug)
# zprof

# Load local machine customizations (not version controlled)
[[ -f "${ZDOTDIR:-$HOME}/.zshrc.local" ]] && source "${ZDOTDIR:-$HOME}/.zshrc.local"
