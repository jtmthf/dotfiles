# Personal Dotfiles

A modern, fast, and comprehensive dotfiles setup optimized for macOS and Linux (including WSL). This configuration prioritizes developer experience, startup speed, and cross-platform compatibility.

## Features

- **Modern Zsh Configuration**: Fast startup with lazy loading and no plugin managers
- **Cross-Platform**: Works on macOS, Linux, and WSL
- **Modern Unix Tools**: Replacements for traditional Unix tools with better UX
- **Development Environment**: Mise for language version management
- **Beautiful Prompt**: Starship for a fast, informative prompt
- **Git**: Global config with delta diffs, SSH commit signing, and sensible defaults
- **SSH**: Multiplexed connections, 1Password agent integration, Colima support
- **Container Development**: Colima for lightweight Docker on macOS
- **Database Services**: Redis and PostgreSQL setup
- **Developer Fonts**: JetBrains Mono, Fira Code, and other Nerd Fonts

## Documentation

- [Architecture](docs/architecture.md) — zsh load order, symlink layout, shared utilities
- [Install Guide](docs/install.md) — prerequisites, what the installer does, rollback
- [Git](docs/git.md) — global git config, SSH signing, local overrides
- [SSH](docs/ssh.md) — connection multiplexing, 1Password agent, platform config
- [Aliases](docs/aliases.md) — shell aliases reference
- [Functions](docs/functions.md) — custom shell functions
- [Homebrew](docs/homebrew.md) — Brewfile and package management
- [Plugins](docs/plugins.md) — zsh plugins
- [Starship](docs/starship.md) — prompt configuration
- [Mise](docs/mise.md) — language version management
- [Ghostty](docs/ghostty.md) — terminal configuration
- [Completions](docs/completions.md) — completion caching
- [Services](docs/services.md) — PostgreSQL, Redis, Colima
- [Colima](docs/colima.md) — Docker via Colima

## Quick Start

```bash
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

## What's Included

### Shell Configuration

- Modern Zsh with optimized settings
- Fast startup through lazy loading
- Syntax highlighting, autosuggestions, and completions
- Comprehensive aliases for modern tools
- Useful functions for development tasks

### Modern Tools

- `bat` - Better cat with syntax highlighting
- `fd` - Better find with intuitive syntax
- `ripgrep` - Better grep that's incredibly fast
- `fzf` - Fuzzy finder for everything
- `zoxide` - Better cd with frecency
- `delta` - Better diff with syntax highlighting
- `dust` - Better du with visualization
- `procs` - Better ps with colors
- `bottom` - Better top with graphs

### Development Environment

- **Mise**: Manages Node.js, Python, Java, Ruby versions
- **Starship**: Fast, customizable prompt
- **Git**: delta pager, histogram diffs, SSH signing, rerere, auto-squash, sensible push/pull defaults
- **SSH**: Connection multiplexing, keepalive, 1Password agent integration
- **Docker**: Managed through Colima on macOS
- **Databases**: PostgreSQL and Redis services

### Aliases & Functions

- Git workflow shortcuts
- Docker management commands
- File operations and navigation
- Network utilities
- System information tools
- Development helpers

## Directory Structure

```
~/.dotfiles/
├── install.sh              # Main installation script
├── Brewfile                 # Homebrew dependencies
├── zsh/
|   ├── .zprofile            # Login shell setup
|   ├── .zshenv             # Environment setup
│   ├── .zshrc              # Main zsh configuration
│   ├── aliases.zsh         # Command aliases
│   ├── functions.zsh       # Custom functions
│   ├── completions.zsh     # Command completions
│   └── plugins/            # Lightweight plugins
├── config/
│   ├── starship.toml       # Starship prompt configuration
│   ├── ghostty/
│   │   └── config          # Ghostty terminal configuration
│   ├── git/
│   │   ├── config          # Global git configuration
│   │   └── ignore          # Global gitignore
│   ├── mise/
│   │   └── config.toml     # Mise configuration
│   └── ssh/
│       └── config          # SSH configuration
└── scripts/
    ├── setup-services.sh   # Redis/Postgres setup
    └── setup-colima.sh     # Colima container setup
```

## Key Commands

### System Management

```bash
# Update all development tools
update-all

# System information
sysinfo

# Benchmark commands
bench "your-command"

# Find large files
findlarge 100M
```

### Development

```bash
# Setup new project
dev-setup my-project

# Git repository cleanup
git-cleanup

# Code statistics
codestats

# Docker cleanup
docker-cleanup
```

### File Operations

```bash
# Create directory and cd into it
mkcd new-directory

# Extract any archive
extract archive.tar.gz

# Backup file with timestamp
backup important-file.txt

# Find and replace in files
findreplace "old-text" "new-text" "*.js"
```

### Network Utilities

```bash
# Check what's using a port
port-check 3000

# Kill process on port
port-kill 3000

# Get weather
weather Nashville

# Generate QR code
qr "Hello World"
```

## Configuration

### Mise (Development Environment)

Configured languages with sensible defaults:

- Node.js: LTS version
- Python: 3.11
- Java: OpenJDK 17
- Ruby: 3.2

### Starship Prompt

Optimized for speed with useful information:

- Git status and branch
- Language versions (when relevant)
- Command duration for long-running commands
- Kubernetes context (when available)
- Cloud provider context

### Services

- PostgreSQL running on port 5432
- Redis running on port 6379
- Both configured to start automatically

## Customization

### Adding Aliases

Edit `~/.dotfiles/zsh/aliases.zsh` and run `reload` to apply.

### Adding Functions

Edit `~/.dotfiles/zsh/functions.zsh` and run `reload` to apply.

### Modifying Prompt

Edit `~/.dotfiles/config/starship.toml` and run `reload` to apply.

### Adding Tools

Add to `Brewfile` and run `brew bundle --file=~/.dotfiles/Brewfile`.

## Performance

This configuration is optimized for speed:

- Zsh starts in < 100ms typically
- Lazy loading of completions and tools
- Minimal plugin overhead
- Efficient prompt rendering

## Troubleshooting

### Slow Startup

```bash
# Profile zsh startup (uncomment lines in .zshrc)
zsh -xvs

# Check what's taking time
time zsh -i -c exit
```

### Plugin Issues

```bash
# Update plugins
cd ~/.dotfiles && git submodule update --remote

# Reinstall plugins
rm -rf ~/.dotfiles/zsh/plugins/*
./install.sh
```

### Service Issues

```bash
# Check service status
brew services list

# Restart services
brew services restart postgresql@14
brew services restart redis
```

## Contributing

1. Fork the repository
2. Make your changes
3. Test on macOS and Linux
4. Submit a pull request

## License

MIT License - feel free to use and modify as needed.
