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

# Worktree-backed tmux session: one session per branch.
#
#   cw <branch>     Create or attach to session for <branch> at $CW_ROOT/<repo>/<branch>
#   cw -l           List existing worktrees
#   cw -r <branch>  Remove worktree and kill its tmux session
#
# Session starts with one pane titled `claude` running Claude Code. Split and
# title the rest yourself per project (`prefix + |`/`-`, `prefix + T`, or
# `prefix + S` for a 3-pane convenience layout).
cw() {
    local cw_root="${CW_ROOT:-$HOME/Worktrees}"
    local action="create"
    local branch=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--list)   action="list"; shift ;;
            -r|--remove) action="remove"; shift; branch="${1:-}"; [[ -n "$branch" ]] && shift ;;
            -h|--help)   action="help"; shift ;;
            -*)          echo "cw: unknown flag: $1" >&2; return 64 ;;
            *)           branch="$1"; shift ;;
        esac
    done

    if [[ "$action" == "help" ]]; then
        cat <<'EOF'
cw — worktree + tmux session per branch

  cw <branch>      Create or attach to session for <branch>
  cw -l            List existing worktrees under $CW_ROOT
  cw -r <branch>   Remove worktree and kill its tmux session

Environment:
  CW_ROOT          Worktree root (default: ~/Worktrees)
EOF
        return 0
    fi

    if [[ "$action" == "list" ]]; then
        if [[ ! -d "$cw_root" ]]; then
            echo "no worktrees ($cw_root does not exist)"
            return 0
        fi
        find "$cw_root" -mindepth 2 -maxdepth 2 -type d | sed "s|^$cw_root/||"
        return 0
    fi

    git rev-parse --show-toplevel &>/dev/null || {
        echo "cw: not inside a git repository" >&2
        return 1
    }
    local main_root repo_name
    main_root="$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')"
    repo_name="$(basename "$main_root")"

    if [[ -z "$branch" ]]; then
        echo "cw: branch name required" >&2
        return 64
    fi

    local wt_path="$cw_root/$repo_name/$branch"
    local session_name="${repo_name}-${branch//\//-}"

    if [[ "$action" == "remove" ]]; then
        if tmux has-session -t "$session_name" 2>/dev/null; then
            tmux kill-session -t "$session_name"
        fi
        if [[ -d "$wt_path" ]]; then
            (cd "$main_root" && git worktree remove --force "$wt_path") || return 1
        fi
        echo "removed: $session_name ($wt_path)"
        return 0
    fi

    if [[ ! -d "$wt_path" ]]; then
        mkdir -p "$cw_root/$repo_name"
        if git -C "$main_root" show-ref --verify --quiet "refs/heads/$branch"; then
            git -C "$main_root" worktree add "$wt_path" "$branch" || return 1
        else
            git -C "$main_root" worktree add -b "$branch" "$wt_path" || return 1
        fi
    fi

    if ! tmux has-session -t "$session_name" 2>/dev/null; then
        tmux new-session -d -s "$session_name" -c "$wt_path" -n main
        tmux select-pane -t "${session_name}:main.1" -T claude
        if command -v claude >/dev/null 2>&1; then
            tmux send-keys -t "${session_name}:main.1" 'claude' Enter
        fi
    fi

    if [[ -n "${TMUX:-}" ]]; then
        tmux switch-client -t "$session_name"
    else
        tmux attach-session -t "$session_name"
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