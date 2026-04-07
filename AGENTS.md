# AGENTS.md

Personal dotfiles for macOS/Linux/WSL. Shell scripts (bash/zsh), managed with Homebrew.

## Commands

```bash
# Install everything (Homebrew, packages, plugins, symlinks, services)
./install.sh

# Dry run (preview changes without modifying anything)
./install.sh --dry-run

# Rollback to most recent backup
./install.sh --rollback

# Reload shell after editing zsh config
exec zsh

# Install Brewfile packages only
brew bundle --file=./Brewfile

# Profile zsh startup time
time zsh -i -c exit
```

## Conventions

- All scripts use `set -euo pipefail`.
- Aliases gate on `command -v` so they degrade gracefully when a tool isn't installed.
- Completions are generated and cached in `$XDG_CACHE_HOME/zsh/completions/` — regenerated only when the binary changes.
- Cross-platform blocks use `$OSTYPE` checks (`darwin*`, `linux-gnu*`) and `$WSL_DISTRO_NAME` for WSL detection.
- The Brewfile uses `if OS.mac?` / `if OS.linux?` guards for platform-specific packages.

## Deep Dive

- [Architecture](docs/architecture.md) — zsh load order, symlink layout, shared utilities
