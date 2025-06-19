# Personal Completions
# Modern tool completions and enhancements

# GitHub CLI completion
if command -v gh &> /dev/null; then
    eval "$(gh completion -s zsh)"
fi

# Docker completion
if command -v docker &> /dev/null; then
    # Docker completion is usually installed with Docker
    if [[ -f /usr/local/etc/bash_completion.d/docker ]]; then
        source /usr/local/etc/bash_completion.d/docker
    fi
fi

# Kubectl completion (if installed)
if command -v kubectl &> /dev/null; then
    source <(kubectl completion zsh)
fi

# Helm completion (if installed)
if command -v helm &> /dev/null; then
    source <(helm completion zsh)
fi

# Terraform completion (if installed)
if command -v terraform &> /dev/null; then
    complete -o nospace -C terraform terraform
fi

# Add custom completion directory to fpath
fpath=(~/.dotfiles/zsh/completions $fpath)

# Custom completions for common tools
_mise_completion() {
    if command -v mise &> /dev/null; then
        eval "$(mise completion zsh)"
    fi
}

# Load mise completion
_mise_completion

# Custom completion for our functions
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