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
brew "delta"         # Better diff
brew "dust"          # Better du
brew "duf"           # Better df
brew "procs"         # Better ps
brew "bottom"        # Better top
brew "hyperfine"      # Benchmarking
brew "tokei"         # Code statistics
brew "tealdeer"      # Better man pages
brew "broot"         # Better tree
brew "sd"            # Better sed
brew "choose"        # Better cut/awk
brew "jq"            # JSON processor
brew "yq"            # YAML processor

# Development tools
brew "git"
brew "gh"            # GitHub CLI
brew "curl"
brew "wget"
brew "httpie"
brew "tree"
brew "tmux"
brew "neovim"
brew "lazygit"
brew "lazydocker"

# Container tools
brew "colima"
brew "docker"
brew "docker-compose"

# Database tools
brew "postgresql@14", restart_service: true
brew "redis", restart_service: true

# Network tools
brew "nmap"
brew "netcat"

# Archive tools
brew "unzip"
brew "p7zip"

# macOS specific
if OS.mac?
  # Fonts
  cask "font-fira-code-nerd-font"
  cask "font-jetbrains-mono-nerd-font"
  cask "font-hack-nerd-font"
  cask "font-source-code-pro"

  # Applications
  cask "iterm2"
  cask "visual-studio-code"
  cask "rectangle"
  cask "alfred"
  cask "raycast"

  # Development
  cask "postman"
  cask "tableplus"
  cask "docker"
end

# Linux specific (including WSL)
if OS.linux?
  # Additional tools for Linux
  brew "gcc"
  brew "make"
  brew "build-essential" if system("command -v apt-get")
end
