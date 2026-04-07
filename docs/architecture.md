# Architecture

The installer (`install.sh`) orchestrates everything: installs Homebrew, runs the Brewfile, clones zsh plugins, creates symlinks into `~/.config/`, and optionally sets up macOS services (PostgreSQL, Redis, Colima).

## Zsh load order

1. `zsh/.zshenv` — XDG dirs, PATH, env vars. Sourced by **all** shells. Must stay lightweight.
2. `zsh/.zprofile` — Homebrew shellenv, mise shims, SSH agent, language paths. Login shells only.
3. `zsh/.zshrc` — Interactive config: completions, aliases, functions, plugins, tool init (starship, fzf, zoxide, mise activate). Sources `aliases.zsh`, `functions.zsh`, `completions.zsh`.

Plugins are git-cloned (not submodules) into `zsh/plugins/`. Syntax highlighting **must** be sourced last.

## Symlink layout

The installer symlinks into `~/.config/` via a bootstrap `~/.zshenv` that sets `ZDOTDIR=$XDG_CONFIG_HOME/zsh`:

- `zsh/*` → `~/.config/zsh/`
- `config/starship.toml` → `~/.config/starship.toml`
- `config/mise/config.toml` → `~/.config/mise/config.toml`
- `config/ghostty/config` → `~/.config/ghostty/config`

## Shared utilities

`lib/logging.sh` provides `log_info`, `log_success`, `log_warning`, `log_error` — sourced by `install.sh` and scripts in `scripts/`.
