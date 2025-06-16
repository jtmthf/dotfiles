# ~/.config/zsh/functions.zsh - Custom functions

# ============================================================================
# FILE AND DIRECTORY OPERATIONS
# ============================================================================

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Move up n directories
up() {
    local d=""
    local limit="${1:-1}"
    for ((i=1; i<=limit; i++)); do
        d="../$d"
    done
    cd "$d"
}

# Find files by name
ff() {
    find . -type f -name "*$1*" 2>/dev/null
}

# Find directories by name
fd() {
    find . -type d -name "*$1*" 2>/dev/null
}

# Show file info
info() {
    if [[ -f "$1" ]]; then
        echo "File: $1"
        echo "Size: $(du -h "$1" | cut -f1)"
        echo "Type: $(file -b "$1")"
        echo "Permissions: $(ls -l "$1" | cut -d' ' -f1)"
        echo "Last modified: $(stat -c %y "$1" 2>/dev/null || stat -f %Sm "$1")"
    elif [[ -d "$1" ]]; then
        echo "Directory: $1"
        echo "Contents: $(ls -1 "$1" | wc -l) items"
        echo "Size: $(du -sh "$1" | cut -f1)"
        echo "Permissions: $(ls -ld "$1" | cut -d' ' -f1)"
    else
        echo "File or directory not found: $1"
    fi
}

# ============================================================================
# ARCHIVE OPERATIONS
# ============================================================================

# Extract any type of archive
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *.xz)        unxz "$1"        ;;
            *.exe)       cabextract "$1"  ;;
            *)           echo "'$1': unrecognized file compression" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Create archive
compress() {
    if [[ -n "$1" ]]; then
        local file="$1"
        case "$2" in
            tar.bz2|tbz2) tar cjf "$file.tar.bz2" "$file" ;;
            tar.gz|tgz)   tar czf "$file.tar.gz" "$file"  ;;
            tar)          tar cf "$file.tar" "$file"      ;;
            bz2)          bzip2 "$file"                   ;;
            gz)           gzip "$file"                    ;;
            zip)          zip -r "$file.zip" "$file"      ;;
            *)            echo "Usage: compress <file> <tar.bz2|tar.gz|tar|bz2|gz|zip>" ;;
        esac
    else
        echo "Usage: compress <file> <format>"
    fi
}

# ============================================================================
# DEVELOPMENT HELPERS
# ============================================================================

# Clone and cd into repository
clone() {
    git clone "$1" && cd "$(basename "$1" .git)"
}

# Create new project directory with git
newproject() {
    if [[ -z "$1" ]]; then
        echo "Usage: newproject <project-name>"
        return 1
    fi
    
    mkdir -p "$1"
    cd "$1"
    git init
    touch README.md .gitignore
    echo "# $1" > README.md
    echo "Created new project: $1"
}

# Quick commit with message
qcommit() {
    git add -A && git commit -m "$1"
}

# Show git log with stats
glog() {
    git log --oneline --graph --decorate --all "${@:-HEAD~10..HEAD}"
}

# Show current branch
current_branch() {
    git branch 2>/dev/null | grep '^*' | cut -d' ' -f2
}

# Push current branch to origin
gpush() {
    local branch=$(current_branch)
    git push origin "$branch"
}

# ============================================================================
# NETWORK AND WEB
# ============================================================================

# Get external IP
myip() {
    curl -s ifconfig.me
}

# Get local IP
localip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ipconfig getifaddr en0
    else
        hostname -I | cut -d' ' -f1
    fi
}

# Check if website is up
isup() {
    local url="$1"
    if curl -s --head "$url" | head -n 1 | grep -q "200 OK"; then
        echo "$url is up"
    else
        echo "$url is down"
    fi
}

# Download file with progress bar
download() {
    if command -v aria2c >/dev/null 2>&1; then
        aria2c --max-connection-per-server=5 --continue "$1"
    else
        wget --progress=bar --show-progress "$1"
    fi
}

# Simple HTTP server
serve() {
    local port="${1:-8000}"
    echo "Starting HTTP server on port $port..."
    python -m http.server "$port"
}

# ============================================================================
# SYSTEM UTILITIES
# ============================================================================

# Show disk usage for current directory
diskusage() {
    du -sh * | sort -hr
}

# Show largest files in directory
largest() {
    find "${1:-.}" -type f -exec du -h {} + | sort -hr | head -20
}

# Show processes using most CPU
topcpu() {
    ps aux --sort=-%cpu | head -20
}

# Show processes using most memory
topmem() {
    ps aux --sort=-%mem | head -20
}

# Kill process by name
killproc() {
    if [[ -z "$1" ]]; then
        echo "Usage: killproc <process-name>"
        return 1
    fi
    
    local pids=$(pgrep -f "$1")
    if [[ -n "$pids" ]]; then
        echo "Killing processes matching '$1':"
        echo "$pids" | xargs ps -p
        echo "$pids" | xargs kill
    else
        echo "No processes found matching '$1'"
    fi
}

# ============================================================================
# TEXT PROCESSING
# ============================================================================

# Count lines in file
lines() {
    wc -l "$1" | cut -d' ' -f1
}

# Remove duplicate lines
dedup() {
    sort "$1" | uniq
}

# Convert text to lowercase
lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Convert text to uppercase
upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# URL encode
urlencode() {
    python -c "import sys, urllib.parse as ul; print(ul.quote_plus(sys.argv[1]))" "$1"
}

# URL decode
urldecode() {
    python -c "import sys, urllib.parse as ul; print(ul.unquote_plus(sys.argv[1]))" "$1"
}

# ============================================================================
# DEVELOPMENT ENVIRONMENT
# ============================================================================

# Quick Node.js project setup
nodeproject() {
    if [[ -z "$1" ]]; then
        echo "Usage: nodeproject <project-name>"
        return 1
    fi
    
    mkdir -p "$1"
    cd "$1"
    npm init -y
    mkdir src test
    touch src/index.js test/index.test.js .gitignore
    echo "node_modules/" > .gitignore
    echo "Created Node.js project: $1"
}

# Quick Python project setup
pyproject() {
    if [[ -z "$1" ]]; then
        echo "Usage: pyproject <project-name>"
        return 1
    fi
    
    mkdir -p "$1"
    cd "$1"
    python -m venv venv
    source venv/bin/activate
    mkdir src tests
    touch src/__init__.py src/main.py tests/__init__.py tests/test_main.py
    touch requirements.txt .gitignore README.md
    echo "venv/" > .gitignore
    echo "__pycache__/" >> .gitignore
    echo "*.pyc" >> .gitignore
    echo "Created Python project: $1"
}

# Activate Python virtual environment
venv() {
    if [[ -f "venv/bin/activate" ]]; then
        source venv/bin/activate
    elif [[ -f ".venv/bin/activate" ]]; then
        source .venv/bin/activate
    else
        echo "No virtual environment found"
        return 1
    fi
}

# ============================================================================
# PRODUCTIVITY HELPERS
# ============================================================================

# Timer function
timer() {
    local seconds="$1"
    local message="${2:-Timer finished}"
    
    if [[ -z "$seconds" ]]; then
        echo "Usage: timer <seconds> [message]"
        return 1
    fi
    
    echo "Timer set for $seconds seconds..."
    sleep "$seconds"
    echo "$message"
    
    # Try to send notification if available
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Timer" "$message"
    elif command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"$message\" with title \"Timer\""
    fi
}

# Generate random password
genpass() {
    local length="${1:-16}"
    openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
}

# Weather information
weather() {
    local location="${1:-}"
    if [[ -n "$location" ]]; then
        curl -s "wttr.in/$location"
    else
        curl -s "wttr.in"
    fi
}

# Quick note taking
note() {
    local note_file="$HOME/notes/$(date +%Y-%m-%d).md"
    mkdir -p "$(dirname "$note_file")"
    
    if [[ -z "$1" ]]; then
        $EDITOR "$note_file"
    else
        echo "## $(date +%H:%M:%S)" >> "$note_file"
        echo "$*" >> "$note_file"
        echo "" >> "$note_file"
        echo "Note added to $note_file"
    fi
}

# ============================================================================
# MACOS SPECIFIC FUNCTIONS
# ============================================================================

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Quick Look
    ql() {
        qlmanage -p "$1" &>/dev/null
    }
    
    # Empty trash
    emptytrash() {
        sudo rm -rfv /Volumes/*/.Trashes
        sudo rm -rfv ~/.Trash
        sudo rm -rfv /private/var/log/asl/*.asl
        echo "Trash emptied"
    }
    
    # Flush DNS
    flushdns() {
        sudo dscacheutil -flushcache
        sudo killall -HUP mDNSResponder
        echo "DNS cache flushed"
    }
    
    # Show/hide hidden files
    showfiles() {
        defaults write com.apple.finder AppleShowAllFiles YES
        killall Finder
        echo "Hidden files shown"
    }
    
    hidefiles() {
        defaults write com.apple.finder AppleShowAllFiles NO
        killall Finder
        echo "Hidden files hidden"
    }
fi

# ============================================================================
# DOCKER HELPERS
# ============================================================================

# Docker cleanup
dockerclean() {
    echo "Cleaning up Docker..."
    docker system prune -af
    docker volume prune -f
    echo "Docker cleanup complete"
}

# Docker container shell
dsh() {
    if [[ -z "$1" ]]; then
        echo "Usage: dsh <container-name-or-id>"
        return 1
    fi
    
    docker exec -it "$1" /bin/bash || docker exec -it "$1" /bin/sh
}

# ============================================================================
# SEARCH HELPERS
# ============================================================================

# Search for text in files
search() {
    if [[ -z "$1" ]]; then
        echo "Usage: search <pattern> [directory]"
        return 1
    fi
    
    local pattern="$1"
    local dir="${2:-.}"
    
    if command -v rg >/dev/null 2>&1; then
        rg "$pattern" "$dir"
    else
        grep -r "$pattern" "$dir"
    fi
}

# Find and replace in files
replace() {
    if [[ -z "$2" ]]; then
        echo "Usage: replace <old> <new> [file-pattern]"
        return 1
    fi
    
    local old="$1"
    local new="$2"
    local pattern="${3:-*}"
    
    if command -v fd >/dev/null 2>&1; then
        fd "$pattern" -x sed -i "s/$old/$new/g" {}
    else
        find . -name "$pattern" -type f -exec sed -i "s/$old/$new/g" {} +
    fi
}