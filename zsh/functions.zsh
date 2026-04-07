# Personal Functions
# Useful utilities and shortcuts

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract various archive formats
extract() {
    if [[ -z "$1" ]]; then
        echo "Usage: extract <archive>"
        return 1
    fi
    
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
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Find and replace in files
findreplace() {
    if [[ $# -ne 3 ]]; then
        echo "Usage: findreplace <search_pattern> <replace_pattern> <file_pattern>"
        return 1
    fi
    
    find . -name "$3" -type f -exec sd "$1" "$2" {} +
}

# Get local IP address (cross-platform)
localip() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ipconfig getifaddr "$(route -n get default 2>/dev/null | awk '/interface:/ {print $2}')"
    else
        hostname -I | awk '{print $1}'
    fi
}

# Quick file backup
backup() {
    if [[ -z "$1" ]]; then
        echo "Usage: backup <file>"
        return 1
    fi
    
    cp "$1" "$1.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Backup created: $1.backup.$(date +%Y%m%d_%H%M%S)"
}

# Get file size in human readable format
filesize() {
    if [[ -z "$1" ]]; then
        echo "Usage: filesize <file>"
        return 1
    fi
    
    if command -v dust &> /dev/null; then
        dust -d0 "$1"
    else
        du -sh "$1"
    fi
}

# Generate random password
genpass() {
    local length=${1:-16}
    openssl rand -base64 32 | cut -c1-$length
}

# Weather function
weather() {
    local location=${1:-}
    curl -s "wttr.in/$location?format=3"
}

# QR code generator
qr() {
    if [[ -z "$1" ]]; then
        echo "Usage: qr <text>"
        return 1
    fi
    
    curl -s "qrenco.de/$1"
}

# Docker cleanup functions
docker-cleanup() {
    echo "Cleaning up Docker..."
    docker system prune -af --volumes
    docker image prune -af
}

docker-stop-all() {
    docker stop $(docker ps -aq) 2>/dev/null || echo "No running containers"
}

docker-rm-all() {
    docker rm $(docker ps -aq) 2>/dev/null || echo "No containers to remove"
}

# Git functions
git-cleanup() {
    echo "Cleaning up Git repository..."
    git branch --merged | grep -v "\*\|main\|master\|develop" | xargs -n 1 git branch -d
    git remote prune origin
    git gc --prune=now
}

git-contributors() {
    git log --format='%aN <%aE>' | sort -u
}

git-stats() {
    echo "Repository Statistics:"
    echo "====================="
    echo "Total commits: $(git rev-list --count HEAD)"
    echo "Total contributors: $(git log --format='%aN' | sort -u | wc -l)"
    echo "Repository size: $(du -sh .git | cut -f1)"
    echo ""
    echo "Top 10 contributors:"
    git log --format='%aN' | sort | uniq -c | sort -rn | head -10
}

# Development environment functions
dev-setup() {
    local project_name=${1:-"new-project"}
    mkdir -p "$project_name"
    cd "$project_name"
    
    # Initialize git
    git init
    
    # Create basic structure
    mkdir -p {src,tests,docs}
    touch README.md .gitignore
    
    # Create basic .gitignore
    cat > .gitignore << 'GITIGNORE'
# Dependencies
node_modules/
venv/
env/
.env

# Build outputs
dist/
build/
*.pyc
__pycache__/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
GITIGNORE
    
    echo "Development environment setup complete for $project_name"
}

# Network utility functions
port-check() {
    if [[ -z "$1" ]]; then
        echo "Usage: port-check <port>"
        return 1
    fi
    
    lsof -i ":$1"
}

port-kill() {
    if [[ -z "$1" ]]; then
        echo "Usage: port-kill <port>"
        return 1
    fi
    
    lsof -ti ":$1" | xargs kill -9
}

# System information
sysinfo() {
    echo "System Information:"
    echo "=================="
    echo "OS: $(uname -s)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime | awk '{print $3,$4}' | sed 's/,//')"
    
    if command -v free &> /dev/null; then
        echo "Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    fi
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS Version: $(sw_vers -productVersion)"
        echo "Memory: $(top -l 1 -s 0 | grep PhysMem | awk '{print $2}')"
    fi
}

# Benchmark function
bench() {
    if [[ -z "$1" ]]; then
        echo "Usage: bench <command>"
        return 1
    fi
    
    if command -v hyperfine &> /dev/null; then
        hyperfine "$1"
    else
        time "$1"
    fi
}

# Code statistics
codestats() {
    if command -v tokei &> /dev/null; then
        tokei
    else
        find . -name "*.py" -o -name "*.js" -o -name "*.go" -o -name "*.rs" -o -name "*.java" | xargs wc -l
    fi
}

# Update all development tools
update-all() {
    echo "Updating all development tools..."
    
    # Homebrew
    if command -v brew &> /dev/null; then
        echo "Updating Homebrew..."
        brew update && brew upgrade && brew cleanup
    fi
    
    # Mise
    if command -v mise &> /dev/null; then
        echo "Updating Mise..."
        mise upgrade
    fi
    
    # Git repositories (plugins)
    echo "Updating Git repositories..."
    local plugins_dir="$HOME/.dotfiles/zsh/plugins"
    for plugin in "$plugins_dir"/*; do
        if [[ -d "$plugin/.git" ]]; then
            echo "Updating $(basename "$plugin")..."
            (cd "$plugin" && git pull)
        fi
    done
    
    echo "All updates complete!"
}

# Find large files
findlarge() {
    local size=${1:-100M}
    find . -type f -size +"$size" -exec ls -lh {} + | sort -k5 -hr
}

# Process monitoring
watch-process() {
    if [[ -z "$1" ]]; then
        echo "Usage: watch-process <process_name>"
        return 1
    fi
    
    watch -n 1 "ps aux | grep '$1' | grep -v grep"
}

# JSON pretty print
json-pretty() {
    if [[ -z "$1" ]]; then
        python3 -m json.tool
    else
        python3 -m json.tool "$1"
    fi
}

# YAML pretty print (requires yq)
yaml-pretty() {
    if command -v yq &> /dev/null; then
        if [[ -z "$1" ]]; then
            yq eval '.' -
        else
            yq eval '.' "$1"
        fi
    else
        echo "yq is required for yaml-pretty function"
    fi
}