# ~/.config/zsh/aliases.zsh - Aliases and shortcuts

# ============================================================================
# BASIC COMMANDS
# ============================================================================

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ~='cd ~'
alias -- -='cd -'

# List files
if command -v exa >/dev/null 2>&1; then
    alias ls='exa --color=auto --group-directories-first'
    alias ll='exa -l --color=auto --group-directories-first'
    alias la='exa -la --color=auto --group-directories-first'
    alias lt='exa --tree --color=auto --group-directories-first'
    alias l='exa -la --color=auto --group-directories-first'
else
    alias ls='ls --color=auto'
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'
fi

# File operations
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias mkdir='mkdir -p'

# Text viewing
if command -v bat >/dev/null 2>&1; then
    alias cat='bat'
    alias less='bat'
else
    alias cat='cat -n'
fi

# Process management
alias ps='ps aux'
alias jobs='jobs -l'

# Disk usage
alias df='df -h'
alias du='du -h'
alias free='free -h'

# ============================================================================
# DEVELOPMENT TOOLS
# ============================================================================

# Git aliases
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gc='git commit -v'
alias gca='git commit -v -a'
alias gcam='git commit -a -m'
alias gcm='git commit -m'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gd='git diff'
alias gdc='git diff --cached'
alias gl='git pull'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias gp='git push'
alias gpom='git push origin main'
alias gr='git remote'
alias gra='git remote add'
alias grv='git remote -v'
alias gs='git status'
alias gst='git stash'
alias gsta='git stash apply'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsts='git stash save'

# Docker
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dex='docker exec -it'
alias dlog='docker logs'
alias dlogf='docker logs -f'

# Node.js & npm
alias n='npm'
alias ni='npm install'
alias nis='npm install --save'
alias nid='npm install --save-dev'
alias nig='npm install --global'
alias nr='npm run'
alias ns='npm start'
alias nt='npm test'
alias nf='npm run format'
alias nl='npm run lint'
alias nb='npm run build'
alias nw='npm run watch'
alias nc='npm run clean'
alias npx='npx --yes'

# Yarn
alias y='yarn'
alias ya='yarn add'
alias yad='yarn add --dev'
alias yag='yarn global add'
alias yr='yarn run'
alias ys='yarn start'
alias yt='yarn test'
alias yb='yarn build'
alias yw='yarn watch'
alias yc='yarn clean'

# Python
alias py='python'
alias py3='python3'
alias pip='pip3'
alias venv='python -m venv'
alias activate='source venv/bin/activate'
alias deactivate='deactivate'
alias pyserver='python -m http.server'
alias pyfmt='black .'
alias pylint='pylint'
alias pytest='pytest -v'

# Ruby
alias be='bundle exec'
alias bi='bundle install'
alias bu='bundle update'
alias rails='bundle exec rails'
alias rake='bundle exec rake'
alias rspec='bundle exec rspec'

# ============================================================================
# SYSTEM ADMINISTRATION
# ============================================================================

# Process management
alias psg='ps aux | grep'
alias top='htop'
alias ports='netstat -tulanp'

# System monitoring
alias meminfo='free -m -l -t'
alias cpuinfo='lscpu'
alias diskusage='df -H'
alias foldersize='du -sh'

# Network
alias ping='ping -c 5'
alias wget='wget -c'
alias curl='curl -L'
alias myip='curl -s ifconfig.me'
alias localip='ipconfig getifaddr en0'

# Archive operations
alias targz='tar -czf'
alias untargz='tar -xzf'
alias tarbz2='tar -cjf'
alias untarbz2='tar -xjf'

# ============================================================================
# SEARCH AND FIND
# ============================================================================

# Better search tools
if command -v rg >/dev/null 2>&1; then
    alias grep='rg'
    alias fgrep='rg -F'
    alias egrep='rg'
else
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep--color=auto'
fi

if command -v fd >/dev/null 2>&1; then
    alias find='fd'
fi

# Common search patterns
alias findname='find . -name'
alias findtext='grep -r'
alias findcode='grep -r --include="*.js" --include="*.ts" --include="*.py" --include="*.rb"'

# ============================================================================
# SHORTCUTS FOR COMMON OPERATIONS
# ============================================================================

# Quick edits
alias zshrc='$EDITOR ~/.zshrc'
alias aliases='$EDITOR ~/.config/zsh/aliases.zsh'
alias vimrc='$EDITOR ~/.vimrc'
alias gitconfig='$EDITOR ~/.gitconfig'

# Reload configuration
alias reload='source ~/.zshrc'
alias rebash='source ~/.bashrc'

# Quick directory access
alias projects='cd ~/Projects'
alias downloads='cd ~/Downloads'
alias documents='cd ~/Documents'
alias desktop='cd ~/Desktop'

# ============================================================================
# UTILITY FUNCTIONS AS ALIASES
# ============================================================================

# Make and enter directory
alias mkcd='mkdir -p "$1" && cd "$1"'

# Extract any archive
alias extract='dtrx'

# Show PATH in readable format
alias path='echo -e ${PATH//:/\\n}'

# Get current weather
alias weather='curl wttr.in'

# Generate random password
alias genpass='openssl rand -base64 32'

# Show file sizes in current directory
alias sizes='du -sh * | sort -hr'

# Show top 10 largest files in current directory
alias largest='find . -type f -exec du -h {} + | sort -hr | head -10'

# Show directory tree
if ! command -v tree >/dev/null 2>&1; then
    alias tree='find . -print | sed -e "s;[^/]*/;|____;g;s;____|; |;g"'
fi

# ============================================================================
# MACOS SPECIFIC
# ============================================================================

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Homebrew
    alias brewup='brew update && brew upgrade && brew cleanup'
    alias brewinfo='brew info'
    alias brewsearch='brew search'
    alias cask='brew install --cask'
    
    # macOS system
    alias showfiles='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder'
    alias hidefiles='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder'
    alias spotlight='sudo mdutil -i on /'
    alias spotlightoff='sudo mdutil -i off /'
    alias flush='dscacheutil -flushcache && killall -HUP mDNSResponder'
    
    # Quick Look
    alias ql='qlmanage -p'
    
    # Open current directory in Finder
    alias finder='open .'
    alias f='open .'
    
    # Copy current path to clipboard
    alias pwd2clip='pwd | pbcopy'
    
    # Empty trash
    alias emptytrash='sudo rm -rfv /Volumes/*/.Trashes; sudo rm -rfv ~/.Trash; sudo rm -rfv /private/var/log/asl/*.asl'
fi

# ============================================================================
# LINUX SPECIFIC
# ============================================================================

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Package management (detect distro)
    if command -v apt >/dev/null 2>&1; then
        alias aptup='sudo apt update && sudo apt upgrade'
        alias aptinstall='sudo apt install'
        alias aptsearch='apt search'
        alias aptremove='sudo apt remove'
        alias aptclean='sudo apt autoremove && sudo apt autoclean'
    elif command -v yum >/dev/null 2>&1; then
        alias yumup='sudo yum update'
        alias yuminstall='sudo yum install'
        alias yumsearch='yum search'
        alias yumremove='sudo yum remove'
    elif command -v dnf >/dev/null 2>&1; then
        alias dnfup='sudo dnf update'
        alias dnfinstall='sudo dnf install'
        alias dnfsearch='dnf search'
        alias dnfremove='sudo dnf remove'
    fi
    
    # System services
    alias services='systemctl list-units --type=service'
    alias startservice='sudo systemctl start'
    alias stopservice='sudo systemctl stop'
    alias restartservice='sudo systemctl restart'
    alias enableservice='sudo systemctl enable'
    alias disableservice='sudo systemctl disable'
    alias statusservice='systemctl status'
    
    # Copy to clipboard (if xclip is available)
    if command -v xclip >/dev/null 2>&1; then
        alias clip='xclip -selection clipboard'
        alias pwd2clip='pwd | xclip -selection clipboard'
    fi
fi

# ============================================================================
# PRODUCTIVITY ALIASES
# ============================================================================

# Time and date
alias now='date +"%T"'
alias nowdate='date +"%d-%m-%Y"'
alias week='date +%V'

# URL encode/decode
alias urlencode='python -c "import sys, urllib.parse as ul; print(ul.quote_plus(sys.argv[1]))"'
alias urldecode='python -c "import sys, urllib.parse as ul; print(ul.unquote_plus(sys.argv[1]))"'

# JSON pretty print
alias json='python -m json.tool'

# Start simple HTTP server
alias serve='python -m http.server 8000'
alias serve3000='python -m http.server 3000'

# Generate UUID
alias uuid='python -c "import uuid; print(uuid.uuid4())"'

# Quick calculator
alias calc='python -c "import sys; print(eval(sys.argv[1]))"'

# ============================================================================
# SAFETY ALIASES
# ============================================================================

# Prevent accidental deletions
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Always use safe directory creation
alias mkdir='mkdir -pv'

# Colorize dangerous commands
alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'
alias chgrp='chgrp --preserve-root'