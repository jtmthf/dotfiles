# Core utilities
brew "coreutils"
brew "findutils"
brew "gnu-tar"
brew "gnu-sed"
brew "gawk"
brew "gnutls"
brew "gnu-indent"
brew "gnu-getopt"
brew "grep"

# Shell and terminal
brew "zsh"
brew "starship"
brew "mise"
brew "zsh-history-substring-search"

# Modern Unix tools
brew "bat"           # Better cat
brew "fd"            # Better find
brew "ripgrep"       # Better grep
brew "fzf"           # Fuzzy finder
brew "zoxide"        # Better cd
brew "git-delta"     # Better diff
brew "dust"          # Better du
brew "duf"           # Better df
brew "procs"         # Better ps
brew "bottom"        # Better top
brew "btop"          # Better top (alternative)
brew "hyperfine"     # Benchmarking
brew "tokei"         # Code statistics
brew "tealdeer"      # Better man pages
brew "broot"         # Better tree
brew "eza"           # Better ls
brew "sd"            # Better sed
brew "choose"        # Better cut/awk
brew "jq"            # JSON processor
brew "yq"            # YAML processor
brew "glow"          # Markdown renderer
brew "csvlens"       # CSV viewer
brew "rsync"         # File sync

# Development tools
brew "git"
brew "gh"            # GitHub CLI
brew "git-lfs"       # Git Large File Storage
brew "graphite"      # Stacked PRs
brew "curl"
brew "wget"
brew "httpie"
brew "tree"
brew "tmux"
brew "neovim"
brew "lazygit"
brew "lazydocker"
brew "act"           # Run GitHub Actions locally
brew "ffmpeg"        # Media processing

# Cloud & infrastructure
brew "awscli"
brew "terraform"

# System tools
brew "htop"
brew "watchman"      # File watcher
brew "imagemagick"
brew "mas"           # Mac App Store CLI

# Container tools
brew "colima"
brew "docker"
brew "docker-compose"

# Database tools
brew "postgresql@17", restart_service: true
brew "redis", restart_service: true

# AI tools
brew "ollama"        # Local LLMs
brew "opencode"      # AI coding CLI

# Network tools
brew "nmap"
brew "netcat"

# Archive tools
brew "unzip"
brew "p7zip"

# macOS specific
if OS.mac?
  # Fonts — plain variants + symbols-only fallback (no patched Nerd Fonts needed)
  cask "font-fira-code"
  cask "font-jetbrains-mono"
  cask "font-hack"
  cask "font-cascadia-code"
  cask "font-source-code-pro"
  cask "font-symbols-only-nerd-font"   # Icon/glyph fallback for all terminals

  # Terminals
  cask "ghostty"
  cask "iterm2"
  cask "warp"

  # Browsers
  cask "firefox"
  cask "google-chrome"
  cask "zen"

  # Editors & IDEs
  cask "visual-studio-code"
  cask "zed"
  cask "jetbrains-toolbox"

  # Design
  cask "figma"

  # Productivity
  cask "notion"
  cask "obsidian"
  cask "slack"
  cask "zoom"

  # Development
  cask "bruno"         # API client
  cask "beekeeper-studio"
  cask "pgadmin4"
  cask "redis-insight"
  cask "ngrok"

  # macOS utilities
  cask "rectangle"
  cask "alfred"
  cask "raycast"
  cask "bartender"
  cask "1password-cli"
  cask "imageoptim"
  cask "qlmarkdown"
  cask "the-unarchiver"

  # AI / LLM
  cask "claude"
  cask "lm-studio"
end

# Linux specific (including WSL)
if OS.linux?
  brew "gcc"
  brew "make"
  brew "build-essential" if system("command -v apt-get")
end
