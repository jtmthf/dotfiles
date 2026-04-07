# Install Guide

## Prerequisites

- **macOS**, **Linux**, or **WSL** (Windows Subsystem for Linux)
- `git` and `curl` available on `$PATH`
- An internet connection (Homebrew and plugin repos are fetched remotely)
- Write access to `~/.config/` and `~/`

Homebrew is installed automatically if it is not already present.

## Quick Start

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./install.sh
```

Preview what will happen without making changes:

```bash
./install.sh --dry-run
```

## What the Installer Does

The script runs through the following steps in order. Each step logs
progress with colored output via `lib/logging.sh`.

### 1. Detect OS

Uses `$OSTYPE` and `$WSL_DISTRO_NAME` to identify one of three
platforms: **macOS**, **Linux**, or **WSL**. The detected platform
controls Homebrew paths and whether macOS-only service setup runs.

### 2. Back Up Existing Dotfiles

Before touching anything, the installer moves existing files
(`.zshenv`, `.zprofile`, `.zshrc`) into a timestamped backup directory:

```
~/.dotfiles_backup_YYYYMMDD_HHMMSS/
```

Only files that already exist are moved. The backup path is printed at
the end of the run.

### 3. Install Homebrew

If `brew` is not found on `$PATH`, Homebrew is installed from the
official install script.

| Platform     | Homebrew prefix                  |
|--------------|----------------------------------|
| macOS        | `/opt/homebrew`                  |
| Linux / WSL  | `/home/linuxbrew/.linuxbrew`     |

On Linux and WSL the shell environment line is also appended to
`~/.profile` so Homebrew is available in future sessions.

### 4. Install Packages

Runs `brew bundle` against the repo's `Brewfile`. The Brewfile uses
`if OS.mac?` / `if OS.linux?` guards for platform-specific packages, so
the same file works on every supported OS.

### 5. Set Up Zsh Plugins

Clones three plugins into `zsh/plugins/` (skipped if already present):

- [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- [zsh-completions](https://github.com/zsh-users/zsh-completions)

### 6. Create Symlinks

The installer writes a bootstrap `~/.zshenv` that sets:

```bash
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:=${HOME}/.config}
export ZDOTDIR=${ZDOTDIR:=${XDG_CONFIG_HOME}/zsh}
source $ZDOTDIR/.zshenv
```

Then it symlinks configuration files from the repo into `~/.config/`:

| Source                          | Target                            |
|---------------------------------|-----------------------------------|
| `zsh/.zshenv`                   | `~/.config/zsh/.zshenv`           |
| `zsh/.zprofile`                 | `~/.config/zsh/.zprofile`         |
| `zsh/.zshrc`                    | `~/.config/zsh/.zshrc`            |
| `config/starship.toml`          | `~/.config/starship.toml`         |
| `config/mise/config.toml`       | `~/.config/mise/config.toml`      |
| `config/ghostty/config`         | `~/.config/ghostty/config`        |

### 7. macOS-Only Services

On macOS the installer additionally runs:

- **`scripts/setup-services.zsh`** -- starts PostgreSQL and Redis via
  Homebrew services.
- **`scripts/setup-colima.zsh`** -- configures Docker through Colima.

These steps are skipped entirely on Linux and WSL.

## Dry Run Mode

```bash
./install.sh --dry-run
```

Every command that would modify the filesystem is replaced with a log
line prefixed `[DRY RUN]`. Nothing is created, moved, or linked. Use
this to review exactly what the installer will do before committing.

## Rollback

```bash
./install.sh --rollback
```

Rollback finds the most recent `~/.dotfiles_backup_*` directory and:

1. Removes all symlinks created during install (`~/.config/zsh/*`,
   `~/.config/starship.toml`, `~/.config/mise/config.toml`,
   `~/.config/ghostty/config`).
2. Copies every backed-up dotfile back to `$HOME`.

After rollback, restart your terminal for changes to take effect.

**Note:** Rollback does not uninstall Homebrew or remove packages
installed via `brew bundle`. It only restores the shell configuration
files that were replaced by symlinks.

## Cross-Platform Notes

- **macOS** -- full support including Homebrew services (PostgreSQL,
  Redis) and Docker via Colima.
- **Linux** -- Homebrew installed under `/home/linuxbrew/.linuxbrew`;
  service setup is skipped.
- **WSL** -- treated as Linux with WSL detection via
  `$WSL_DISTRO_NAME`; same behavior as native Linux.
- The `Brewfile` handles platform differences internally with
  `if OS.mac?` / `if OS.linux?` guards.
- Aliases in the zsh configuration gate on `command -v` so they degrade
  gracefully when a tool is not installed.

## Troubleshooting

**Homebrew not found after install (Linux/WSL)**

The installer adds Homebrew to `~/.profile`, but that file is only
sourced by login shells. If `brew` is not on your path, run:

```bash
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

**Zsh config not loading**

Confirm `~/.zshenv` exists and contains the `ZDOTDIR` bootstrap. Then
verify the symlinks point to valid files:

```bash
ls -la ~/.config/zsh/
```

**Plugin directory missing or empty**

Re-run the installer or clone manually:

```bash
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git zsh/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions.git zsh/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-completions.git zsh/plugins/zsh-completions
```

**No backup found during rollback**

Rollback looks for directories matching `~/.dotfiles_backup_*`. If none
exist (for example, if they were manually deleted), rollback will exit
with an error. In that case, remove the symlinks manually and recreate
your dotfiles.

**Profiling slow shell startup**

```bash
time zsh -i -c exit
```

This measures total startup time. If it is unusually slow, check
completion caching and plugin load order in `.zshrc`.
