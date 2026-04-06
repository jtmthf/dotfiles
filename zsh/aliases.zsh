# Personal Aliases
# Modern replacements and common shortcuts

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ~='cd ~'
alias -- -='cd -'

# Modern ls replacements
if command -v eza &> /dev/null; then
    alias ls='eza --group-directories-first'
    alias la='eza -la --group-directories-first'
    alias ll='eza -l --group-directories-first'
    alias lt='eza --tree --level=2'
    alias lta='eza --tree --level=2 -a'
else
    alias ls='ls --color=auto'
    alias la='ls -la'
    alias ll='ls -l'
fi

# Modern cat replacement
if command -v bat &> /dev/null; then
    alias cat='bat'
    alias catp='bat --plain'
fi

# Modern grep replacement
if command -v rg &> /dev/null; then
    alias grep='rg'
fi

# Modern find replacement
if command -v fd &> /dev/null; then
    alias find='fd'
fi

# Modern du replacement
if command -v dust &> /dev/null; then
    alias du='dust'
fi

# Modern df replacement
if command -v duf &> /dev/null; then
    alias df='duf'
fi

# Modern ps replacement
if command -v procs &> /dev/null; then
    alias ps='procs'
fi

# Modern top replacement
if command -v btm &> /dev/null; then
    alias top='btm'
fi

# Git aliases
alias g='git'
alias ga='git add'
alias gaa='git add .'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit -am'
alias gp='git push'
alias gpl='git pull'
alias gs='git status'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gm='git merge'
alias gr='git rebase'
alias gl='git log --oneline --graph'
alias gla='git log --oneline --graph --all'
alias gst='git stash'
alias gsp='git stash pop'

# Enhanced git with lazygit
if command -v lazygit &> /dev/null; then
    alias lg='lazygit'
fi

# Docker aliases
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias drmi='docker rmi'
alias drm='docker rm'
alias dexec='docker exec -it'
alias dlogs='docker logs'
alias dstop='docker stop'
alias dstart='docker start'

# Enhanced docker with lazydocker
if command -v lazydocker &> /dev/null; then
    alias ld='lazydocker'
fi

# Development aliases
alias v='nvim'
alias vim='nvim'
alias c='code'
alias py='python3'
alias pip='pip3'
alias serve='python3 -m http.server'
alias json='python3 -m json.tool'

# Network aliases
alias ping='ping -c 5'
alias wget='wget -c'
alias myip='curl ifconfig.me'
alias localip='ipconfig getifaddr en0'
alias ports='netstat -tulanp'

# System aliases
alias h='history'
alias j='jobs'
alias path='echo $PATH | tr ":" "\n"'
alias reload='exec zsh'
alias cls='clear'

# Archive aliases
alias tgz='tar -czf'
alias untgz='tar -xzf'
alias tbz='tar -cjf'
alias untbz='tar -xjf'

# macOS specific aliases
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias flush='dscacheutil -flushcache && killall -HUP mDNSResponder'
    alias lscleanup='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user && killall Finder'
    alias show='defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder'
    alias hide='defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder'
    alias hidedesktop='defaults write com.apple.finder CreateDesktop -bool false && killall Finder'
    alias showdesktop='defaults write com.apple.finder CreateDesktop -bool true && killall Finder'
    alias airport='/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport'
    alias emptytrash='sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; sudo rm -rfv /private/var/log/asl/*.asl; sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV* "delete from LSQuarantineEvent"'
fi

# Homebrew aliases
alias br='brew'
alias bri='brew install'
alias brs='brew search'
alias bro='brew outdated'
alias bru='brew update && brew upgrade'
alias brc='brew cleanup'

# Mise aliases
alias mi='mise'
alias mii='mise install'
alias mil='mise list'
alias miu='mise use'
alias mir='mise remove'

# Utility aliases
alias week='date +%V'
alias timer='echo "Timer started. Stop with Ctrl-D." && date && time cat && date'
alias urlencode='python3 -c "import sys, urllib.parse as ul; print(ul.quote_plus(sys.argv[1]))"'
alias urldecode='python3 -c "import sys, urllib.parse as ul; print(ul.unquote_plus(sys.argv[1]))"'
alias base64encode='python3 -c "import sys, base64; print(base64.b64encode(sys.argv[1].encode()).decode())"'
alias base64decode='python3 -c "import sys, base64; print(base64.b64decode(sys.argv[1]).decode())"'

# Quick file operations
alias mk='mkdir -p'
alias md='mkdir -p'
alias rd='rmdir'
alias rf='rm -rf'

# Process management
alias psg='ps aux | grep'
alias killall='killall -v'

# Quick edits
alias zshrc='nvim $ZDOTDIR/.zshrc'
alias aliases='nvim $DOTFILES/zsh/aliases.zsh'
alias functions='nvim $DOTFILES/zsh/functions.zsh'

# Quick navigation to common directories
alias dl='cd ~/Downloads'
alias dt='cd ~/Desktop'
alias docs='cd ~/Documents'
alias dev='cd ~/Development'
alias proj='cd ~/Projects'
