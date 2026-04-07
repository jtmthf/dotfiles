# Homebrew

The `Brewfile` is the single source of truth for all packages, applications, and fonts managed by Homebrew. It is organized by category and uses platform guards (`if OS.mac?` / `if OS.linux?`) so a single file works across macOS and Linux/WSL.

## Installing and updating

```bash
# Install everything in the Brewfile
brew bundle --file=./Brewfile

# Or run the full installer, which handles Homebrew itself plus the Brewfile
./install.sh
```

Shell aliases (defined in `zsh/aliases.zsh`) make day-to-day management faster:

| Alias | Command | Purpose |
|-------|---------|---------|
| `br`  | `brew` | Shorthand for brew |
| `bri` | `brew install` | Install a formula or cask |
| `brs` | `brew search` | Search for packages |
| `bro` | `brew outdated` | List packages with available updates |
| `bru` | `brew update && brew upgrade` | Update Homebrew and upgrade all packages |
| `brc` | `brew cleanup` | Remove old versions and cache files |

After adding a new entry to the Brewfile, run `brew bundle --file=./Brewfile` to install it.

## What is included

### Core utilities

GNU replacements for the BSD tools that ship with macOS. These provide consistent cross-platform behavior and are placed on `$PATH` with their default names via Homebrew's `gnubin` directories.

- coreutils, findutils, gnu-tar, gnu-sed, gawk, gnutls, gnu-indent, gnu-getopt, grep

### Shell and terminal

- **zsh** -- Primary shell.
- **starship** -- Cross-shell prompt with minimal config (`config/starship.toml`).
- **mise** -- Polyglot runtime manager (Node, Python, Ruby, Go, etc.).
- **zsh-history-substring-search** -- Fish-style history search bound to up/down arrows.

### Modern Unix tools

Each of these replaces (or supplements) a traditional Unix command with a faster, more ergonomic alternative. Aliases in `zsh/aliases.zsh` wire most of them in as default commands.

| Tool | Replaces | Notes |
|------|----------|-------|
| bat | cat | Syntax highlighting, Git integration, paging |
| fd | find | Simpler syntax, respects `.gitignore` |
| ripgrep (`rg`) | grep | Extremely fast recursive search |
| fzf | -- | General-purpose fuzzy finder (files, history, branches) |
| zoxide | cd | Frecency-based directory jumping |
| git-delta | diff | Side-by-side diffs with syntax highlighting |
| dust | du | Visual disk usage tree |
| duf | df | Human-readable disk free output |
| procs | ps | Colorized, searchable process listing |
| bottom (`btm`) | top | Terminal system monitor with graphs |
| btop | top | Alternative system monitor (resource-rich UI) |
| hyperfine | time | Statistical command benchmarking |
| tokei | cloc | Fast code statistics by language |
| tealdeer (`tldr`) | man | Community-driven command examples |
| broot | tree | Interactive directory navigator |
| eza | ls | Colorized listing with Git status |
| sd | sed | Simpler find-and-replace syntax |
| choose | cut/awk | Human-friendly field selection |
| jq | -- | JSON processor |
| yq | -- | YAML/TOML/XML processor |
| glow | -- | Terminal Markdown renderer |
| csvlens | -- | Interactive CSV viewer |
| rsync | cp (for large/remote copies) | Resumable, delta-based file sync |

### Development tools

- **git**, **gh** (GitHub CLI), **git-lfs**, **graphite** (stacked PRs)
- **curl**, **wget**, **httpie** -- HTTP clients
- **tree** -- Directory listing
- **tmux** -- Terminal multiplexer
- **neovim** -- Editor
- **lazygit**, **lazydocker** -- TUI wrappers for Git and Docker
- **act** -- Run GitHub Actions locally
- **ffmpeg** -- Media encoding and processing

### Cloud and infrastructure

- **awscli** -- AWS command-line interface
- **terraform** -- Infrastructure as code

### Container tools

- **colima** -- Lightweight container runtime for macOS (replaces Docker Desktop)
- **docker**, **docker-compose** -- Container engine and orchestration

### Database tools

Both are configured with `restart_service: true`, so Homebrew starts them as background services automatically.

- **postgresql@17** -- Relational database
- **redis** -- In-memory data store

### AI tools

- **ollama** -- Run large language models locally
- **opencode** -- AI coding CLI

### System, network, and archive tools

- **htop** -- Interactive process viewer
- **watchman** -- File system watcher (used by Metro, Jest, etc.)
- **imagemagick** -- Image manipulation from the command line
- **mas** -- Mac App Store CLI (install/update App Store apps from the terminal)
- **nmap**, **netcat** -- Network scanning and diagnostics
- **unzip**, **p7zip** -- Archive extraction

## Platform-specific packages

### macOS only (casks)

Casks are GUI applications installed only on macOS, wrapped in the `if OS.mac?` guard.

**Fonts** -- Plain variants of popular coding fonts plus a symbols-only Nerd Font for glyph fallback. No patched Nerd Fonts are needed because the symbols-only font provides icon coverage for any terminal that supports fallback fonts.

- Fira Code, JetBrains Mono, Hack, Cascadia Code, Source Code Pro
- Symbols Only Nerd Font

**Terminals** -- Ghostty, iTerm2, Warp

**Browsers** -- Firefox, Google Chrome, Zen

**Editors and IDEs** -- Visual Studio Code, Zed, JetBrains Toolbox

**Design** -- Figma

**Productivity** -- Notion, Obsidian, Slack, Zoom

**Development** -- Bruno (API client), Beekeeper Studio, pgAdmin4, Redis Insight, ngrok

**Utilities** -- Rectangle, Alfred, Raycast, Bartender, 1Password CLI, ImageOptim, qlmarkdown (Quick Look Markdown preview), The Unarchiver

**AI** -- Claude, LM Studio

### Linux only

Added inside the `if OS.linux?` guard. These provide the C/C++ toolchain that macOS gets from Xcode Command Line Tools.

- gcc, make
- build-essential (only installed when `apt-get` is available, i.e., Debian/Ubuntu)

## Customizing the Brewfile

1. Open `Brewfile` and add a new line under the appropriate category heading.
2. Use `brew "package-name"` for CLI formulae or `cask "app-name"` for GUI applications.
3. Wrap platform-specific entries in the existing `if OS.mac?` or `if OS.linux?` blocks.
4. For services that should start automatically, pass `restart_service: true` (e.g., `brew "redis", restart_service: true`).
5. Run `brew bundle --file=./Brewfile` to install the new entry.
6. If the new tool should replace a built-in command, add an alias in `zsh/aliases.zsh` gated on `command -v` so the config degrades gracefully when the tool is not installed.
