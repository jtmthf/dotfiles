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
- `config/tmux/tmux.conf` → `~/.config/tmux/tmux.conf`
- `config/sesh/sesh.toml` → `~/.config/sesh/sesh.toml`
- `config/ssh/config` → `~/.ssh/config`
- `config/git/config` → `~/.config/git/config`
- `config/git/ignore` → `~/.config/git/ignore`
- `config/zed/settings.json` → `~/.config/zed/settings.json`
- `config/gh/config.yml` → `~/.config/gh/config.yml`
- `config/claude/settings.json` → `~/.claude/settings.json`
- `config/claude/CLAUDE.md` → `~/.claude/CLAUDE.md`
- `config/claude/TMUX.md` → `~/.claude/TMUX.md`
- `config/claude/SEARCH.md` → `~/.claude/SEARCH.md`
- `config/claude/WEB.md` → `~/.claude/WEB.md`

One directory is written (not symlinked) at install time via `playwright-cli install --skills`:
- `~/.claude/skills/playwright-cli/` — browser automation skill for Claude Code (sourced from the globally installed `@playwright/cli` npm package)

Two files are written (not symlinked) at install time:
- `~/.ssh/config.local` — platform-specific `IdentityAgent` path for 1Password SSH agent
- `~/.config/git/config.local` — local git identity overrides (`user.name`, `user.email`, `user.signingKey`); created empty if absent

Note: `~/.claude/` is a non-XDG exception (like `~/.ssh/`); Claude Code does not follow the `~/.config/` convention.

## Worktree sessions (`scripts/cw/`)

`cw` runs one git worktree per branch, each backed by a tmux session holding one
or more tracked Claude Code sessions. `scripts/cw/cw` is the CLI, `cw-lib.sh` the
shared library (paths, manifest schema, zoxide, waiting markers), and
`cw-dashboard.sh` + `hooks/*.sh` the dashboard popup and Claude
Stop/UserPromptSubmit hooks. `install.sh` (`setup_cw`) makes them executable and
merges the hooks into `~/.claude/settings.json`; the `cw` shell function invokes
the scripts by path, so nothing is added to `PATH`.

Worktrees live *inside* the repo at `<repo>/.claude/worktrees/<slug>` — the same
directory Claude Code's native `claude --worktree` uses — kept out of the main
checkout's `git status` via `.git/info/exclude`. Runtime state lives outside the
repo under `${XDG_STATE_HOME:-~/.local/state}/cw/`:

- `manifest.json` — worktrees, their tmux session names, notes, and Claude session
  ids; mutated atomically through a jq-program-plus-`mv` under a `mkdir` lock.
- `waiting/<uuid>` — one empty file per Claude session awaiting input.
- `pr-cache.json` — cached PR status for the dashboard.

See [Worktrees](worktrees.md) for the full workflow.

## Shared utilities

`lib/logging.sh` provides `log_info`, `log_success`, `log_warning`, `log_error` — sourced by `install.sh` and scripts in `scripts/`.
