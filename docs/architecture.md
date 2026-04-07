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
- `config/ssh/config` → `~/.ssh/config`
- `config/git/config` → `~/.config/git/config`
- `config/git/ignore` → `~/.config/git/ignore`
- `config/claude/settings.json` → `~/.claude/settings.json`
- `config/claude/CLAUDE.md` → `~/.claude/CLAUDE.md`

Two files are written (not symlinked) at install time:
- `~/.ssh/config.local` — platform-specific `IdentityAgent` path for 1Password SSH agent
- `~/.config/git/config.local` — local git identity overrides (`user.name`, `user.email`, `user.signingKey`); created empty if absent

Note: `~/.claude/` is a non-XDG exception (like `~/.ssh/`); Claude Code does not follow the `~/.config/` convention.

## Shared utilities

`lib/logging.sh` provides `log_info`, `log_success`, `log_warning`, `log_error` — sourced by `install.sh` and scripts in `scripts/`.
