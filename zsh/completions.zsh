# Personal Completions
# Cached completion generation for fast startup

# Cache directory for generated completions
_comp_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
mkdir -p "$_comp_cache"

# Helper: generate and cache a completion file if stale
# Usage: _cache_completion <name> <binary> <gen_command...>
_cache_completion() {
    local name="$1" bin="$2"; shift 2
    local cache_file="$_comp_cache/_$name"
    local bin_path="${commands[$bin]:-}"

    [[ -z "$bin_path" ]] && return

    if [[ ! -f "$cache_file" ]] || [[ "$bin_path" -nt "$cache_file" ]]; then
        "$@" > "$cache_file" 2>/dev/null
    fi
    source "$cache_file"
}

# GitHub CLI completion
_cache_completion gh gh gh completion -s zsh

# Docker completion (use native zsh completion if available)
if (( $+commands[docker] )); then
    _cache_completion docker docker docker completion zsh
fi

# Kubectl completion (if installed)
_cache_completion kubectl kubectl kubectl completion zsh

# Helm completion (if installed)
_cache_completion helm helm helm completion zsh

# Terraform completion (if installed)
if (( $+commands[terraform] )); then
    complete -o nospace -C terraform terraform
fi

# Mise completion
_cache_completion mise mise mise completion zsh

# Add custom completion directory to fpath
fpath=(~/.dotfiles/zsh/completions $fpath)

# Custom completions for our functions
_extract() {
    local state
    _arguments \
        '1:archive file:_files -g "*.tar.gz *.tar.bz2 *.zip *.rar *.7z *.tar *.gz *.bz2"'
}

_backup() {
    _arguments \
        '1:file to backup:_files'
}

_port-check() {
    _arguments \
        '1:port number:'
}

_port-kill() {
    _arguments \
        '1:port number:'
}

# Register completions
compdef _extract extract
compdef _backup backup
compdef _port-check port-check
compdef _port-kill port-kill

# Enable completion for aliases
compdef g=git
compdef v=nvim
compdef c=code
