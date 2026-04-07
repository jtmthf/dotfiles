# Zsh Configuration

This document covers the Zsh setup in this dotfiles repo: load order, shell options, history, completions, tool integrations, performance optimizations, and how to customize.

## File Layout

The Zsh configuration is split across three files in `zsh/`, each sourced at a different stage of shell startup:

| File | When sourced | Purpose |
|------|-------------|---------|
| `.zshenv` | Every shell (interactive, login, scripts, subshells) | Environment variables and PATH |
| `.zprofile` | Login shells only (first shell after login/reboot) | Expensive one-time setup |
| `.zshrc` | Interactive shells only | Options, completions, plugins, aliases |

Two supporting files are loaded by `.zshrc`:

| File | Purpose |
|------|---------|
| `aliases.zsh` | Command aliases, organized by category |
| `functions.zsh` | Shell functions and utilities |
| `completions.zsh` | Cached completion generation and custom completions |

## Symlink Bootstrap

The repo does not overwrite `~/.zshenv` directly. Instead, `install.sh` writes a small bootstrap file at `~/.zshenv` that sets `ZDOTDIR` and delegates:

```zsh
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:=$HOME/.config}
export ZDOTDIR=${ZDOTDIR:=${XDG_CONFIG_HOME}/zsh}
source $ZDOTDIR/.zshenv
```

Then it symlinks the repo's zsh files into `~/.config/zsh/`:

```
~/.config/zsh/.zshenv   -> ~/.dotfiles/zsh/.zshenv
~/.config/zsh/.zprofile -> ~/.dotfiles/zsh/.zprofile
~/.config/zsh/.zshrc    -> ~/.dotfiles/zsh/.zshrc
```

This keeps `$HOME` clean and places all Zsh config under XDG-compliant paths.

## Load Order Detail

### 1. `.zshenv` -- Environment Foundation

This file runs for every Zsh invocation, including non-interactive scripts and subshells. It must stay lightweight.

**XDG Base Directories.** Defines `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, and `XDG_STATE_HOME` with standard defaults, then creates them if missing. Nearly everything else in the config references these.

**PATH construction.** Uses `typeset -U path PATH` to guarantee no duplicates, then builds the path array in priority order: Homebrew paths (macOS and Linux), user local paths, system paths. The line `path=($^path(N-/))` removes any entries that do not exist on disk, keeping PATH clean across platforms.

**Core variables.** Sets `LANG`/`LC_ALL` to `en_US.UTF-8`, `EDITOR`/`VISUAL` to `nvim`, `PAGER` to `less`, and `LESS` flags for colored output, long prompt, case-insensitive search, and context lines. History file is placed at `$XDG_DATA_HOME/zsh/history`.

**Homebrew controls.** Disables auto-update (`HOMEBREW_NO_AUTO_UPDATE=1`) and analytics (`HOMEBREW_NO_ANALYTICS=1`) to avoid unexpected network calls during installs.

**Mise directories.** Points `MISE_DATA_DIR`, `MISE_CONFIG_DIR`, and `MISE_CACHE_DIR` to XDG locations.

### 2. `.zprofile` -- Login Shell Setup

Runs once per session. This is where expensive operations live.

**Homebrew shellenv.** Detects the Homebrew prefix across macOS (`/opt/homebrew`, `/usr/local`) and Linux (`/home/linuxbrew/.linuxbrew`) and runs `brew shellenv` only when `HOMEBREW_PREFIX` is not already set.

**Mise shims.** Activates mise in shim mode for non-interactive sessions so tools like `node` and `python` resolve correctly in scripts.

**Platform-specific setup:**
- macOS: Adds Cryptexes to PATH, starts SSH agent, loads keys from Keychain via `ssh-add --apple-load-keychain`.
- Linux/WSL: Starts SSH agent, sets `DISPLAY` for WSL GUI forwarding.

**Language toolchains.** Configures `JAVA_HOME` via mise, `GOPATH`/`GOBIN` for Go, and Cargo bin for Rust. Python and Ruby are managed entirely by mise.

**First-time setup.** On initial login, creates `~/Development` and `~/Projects`, prints an SSH key reminder if none exists, then writes a marker file so the checks do not repeat.

**Brew prefix cache.** Caches the output of `brew --prefix` to `$XDG_CACHE_HOME/zsh/brew_prefix`, invalidating only when the brew binary changes. This avoids a slow subprocess call on every login.

### 3. `.zshrc` -- Interactive Shell

Everything the user sees and interacts with. Starts with an early exit guard (`[[ $- != *i* ]] && return`).

## Shell Options

The following `setopt` calls configure interactive behavior:

**Navigation:**
- `AUTO_CD` -- Type a directory name to cd into it without the `cd` command.
- `AUTO_PUSHD` / `PUSHD_IGNORE_DUPS` / `PUSHD_SILENT` -- Every cd pushes to a directory stack. Use `dirs -v` to list, `cd -N` to jump back.

**Globbing:**
- `GLOB_DOTS` -- Globs match dotfiles without needing a leading dot.
- `EXTENDED_GLOB` -- Enables `~`, `^`, and `#` glob operators.

**History (see also the History section below):**
- `SHARE_HISTORY` -- All terminal sessions share a single history file.
- `INC_APPEND_HISTORY` -- Commands are written to the history file immediately, not at shell exit.
- `HIST_IGNORE_DUPS` / `HIST_IGNORE_ALL_DUPS` / `HIST_SAVE_NO_DUPS` -- Deduplication at multiple levels.
- `HIST_IGNORE_SPACE` -- Commands prefixed with a space are not recorded (useful for secrets).
- `HIST_REDUCE_BLANKS` -- Strips extraneous whitespace before saving.
- `HIST_VERIFY` -- Expanding a history reference (e.g., `!!`) shows the command first instead of executing immediately.

**Correction:**
- `CORRECT` -- Offers correction for mistyped commands.
- `NO_CORRECT_ALL` -- Does not attempt to correct arguments, only the command name.

**Completion:**
- `COMPLETE_IN_WORD` -- Tab completion works from both ends of the cursor.
- `ALWAYS_TO_END` -- Moves cursor to end of word after completion.
- `AUTO_MENU` / `AUTO_LIST` -- Tab cycles through a completion menu.
- `NO_MENU_COMPLETE` -- Does not auto-select the first match; lets you choose.
- `AUTO_PARAM_SLASH` -- Adds a trailing slash after completing a directory.

**Misc:**
- `NO_FLOW_CONTROL` -- Disables Ctrl-S/Ctrl-Q terminal flow control so those keys are available for other bindings.

## History

```
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=$XDG_DATA_HOME/zsh/history
```

With `SHARE_HISTORY` and `INC_APPEND_HISTORY` both enabled, commands appear across sessions in near-real-time. The combination of `HIST_IGNORE_DUPS`, `HIST_IGNORE_ALL_DUPS`, and `HIST_SAVE_NO_DUPS` prevents the file from filling with repeated entries.

Prefix a command with a space to keep it out of history entirely (`HIST_IGNORE_SPACE`).

## Completion System

### compinit Optimization

The completion system (`compinit`) rebuilds its dump file at most once every 24 hours:

```zsh
for dump in $ZDOTDIR/.zcompdump(#qN.mh+24); do
    compinit
    ...
done
compinit -C
```

If the dump is less than 24 hours old, `compinit -C` skips the expensive security check and uses the cached dump directly. When the dump is regenerated, it is compiled to `.zcompdump.zwc` with `zcompile` for faster loading.

### Completion Styling

Key `zstyle` settings:

- **Menu selection** (`menu select`) -- Arrow keys navigate a completion menu instead of cycling inline.
- **Case-insensitive matching** -- `m:{[:lower:][:upper:]}={[:upper:][:lower:]}` matches regardless of case, with additional fuzzy matchers for separators like `-`, `_`, and `.`.
- **LS_COLORS integration** -- File completions are colored to match your `ls` output.
- **Caching** -- Completion results are cached in `$XDG_CACHE_HOME/zsh/zcompcache`.
- **Process completion** -- Kill/process completions show PID, user, and command with color coding.
- **Formatted output** -- Descriptions, corrections, and warnings use colored formatting.

### Cached Completion Generation

`completions.zsh` defines a `_cache_completion` helper that generates completion files for CLI tools and caches them. The cache is invalidated when the binary changes (checked via file modification time). Tools with cached completions: `gh`, `docker`, `kubectl`, `helm`, `mise`. Terraform uses its built-in `complete -C` mechanism.

Custom completions are also defined for repo-specific functions: `extract`, `backup`, `port-check`, and `port-kill`. Alias completions are wired up so `g` completes like `git`, `v` like `nvim`, and `c` like `code`.

## Tool Integrations

All tool integrations gate on `command -v` so they degrade gracefully when a tool is not installed.

### Prompt: Starship

Starship is initialized directly (not deferred) since it is fast. Configuration lives in its own config file, not in the Zsh config.

### Fuzzy Finder: fzf

Loads key bindings and completions from the Homebrew-installed fzf. Configured with:

- `FZF_DEFAULT_COMMAND` -- Uses `fd` to find files, respecting `.gitignore`, including hidden files.
- `Ctrl-T` -- Fuzzy file finder with `bat` preview.
- `Alt-C` -- Fuzzy directory changer with `eza` tree preview.
- `Ctrl-R` -- Fuzzy history search (provided by fzf key bindings).
- Visual: 40% height, reverse layout, border, 16-color palette.

### Directory Jumping: zoxide

Initialized with `--cmd cd`, which replaces the built-in `cd` command. Zoxide tracks directory usage and lets you jump to frequently visited directories with partial names (e.g., `cd proj` jumps to `~/Projects` if you visit it often).

### Runtime Manager: mise

Activated twice in different modes:
- `.zprofile`: Shim mode (`--shims`) for non-interactive sessions.
- `.zshrc`: Full activation with hooks for interactive sessions, enabling automatic version switching on directory change.

### Pager: bat

In interactive shells, `PAGER` is overridden to `bat` (the `.zshenv` default of `less` is kept for non-interactive use). Man pages are piped through bat with the `man` language for syntax highlighting. Theme is set to `TwoDark`.

### Browser

Set automatically per platform: `open` on macOS, `wslview` on WSL, `xdg-open` on Linux.

## Plugins

Plugins are cloned as Git repos into `zsh/plugins/` by `install.sh`. Load order matters:

1. **zsh-completions** -- Loaded first. Adds its `src/` directory to `fpath` to extend the completion system with additional definitions.
2. **zsh-autosuggestions** -- Suggests commands as you type based on history and completions (async). Strategy is `(history completion)`, with a 20-character buffer max and muted highlight color.
3. **zsh-history-substring-search** -- Binds Up/Down arrows to search history by the current line prefix. Also binds `Ctrl-R` for incremental backward search and Delete for delete-char.
4. **zsh-syntax-highlighting** -- Must be loaded last (per its documentation). Enables `main`, `brackets`, and `pattern` highlighters with a custom color scheme covering commands, strings, options, redirections, and more.

## Aliases

Aliases live in `aliases.zsh` and follow a few conventions:

- Modern tool replacements gate on `command -v`: `eza` replaces `ls`, `bat` replaces `cat`, `duf` replaces `df`, `lazygit` provides `lg`, `lazydocker` provides `ld`.
- If the modern tool is not installed, the alias falls back to the standard command.
- Categories: navigation (`..`, `...`), git (`g`, `ga`, `gc`, `gs`, etc.), docker (`d`, `dc`, `dps`), development (`v`, `vim`, `py`), network (`myip`, `ports`), system (`reload`, `path`), Homebrew (`bru`, `brc`), mise (`mi`, `mii`), macOS-specific (`flush`, `show`/`hide`, `emptytrash`), quick edits (`zshrc`, `aliases`, `functions`), and directory shortcuts (`dev`, `proj`, `dl`).

## Functions

Functions live in `functions.zsh`. Highlights:

| Function | Description |
|----------|-------------|
| `mkcd` | Create a directory and cd into it |
| `extract` | Extract any common archive format |
| `findreplace` | Find-and-replace across files using `sd` |
| `localip` | Show local IP (cross-platform) |
| `backup` | Timestamped file backup |
| `filesize` | Human-readable file size (uses `dust` if available) |
| `genpass` | Generate a random password |
| `weather` | Current weather via wttr.in |
| `qr` | Generate a QR code in the terminal |
| `docker-cleanup` | Prune all Docker resources |
| `git-cleanup` | Delete merged branches, prune remotes, GC |
| `git-stats` | Repository statistics summary |
| `dev-setup` | Scaffold a new project with git, directories, `.gitignore` |
| `port-check` / `port-kill` | Check or kill a process on a given port |
| `sysinfo` | System information summary (cross-platform) |
| `bench` | Benchmark a command (uses `hyperfine` if available) |
| `codestats` | Line counts by language (uses `tokei` if available) |
| `update-all` | Update Homebrew, mise, and zsh plugins in one command |
| `findlarge` | Find files larger than a given size |
| `watch-process` | Live-watch a process by name |
| `json-pretty` / `yaml-pretty` | Pretty-print JSON or YAML |

## Performance Optimizations

Several techniques keep shell startup fast:

1. **Split load order.** Expensive operations (Homebrew shellenv, mise shims, language toolchain detection) run only in login shells via `.zprofile`, not on every new terminal tab.
2. **Guarded Homebrew init.** `brew shellenv` runs only when `HOMEBREW_PREFIX` is unset, avoiding redundant work in nested shells.
3. **Daily compinit.** The completion dump is rebuilt at most once per 24 hours. The rest of the time, `compinit -C` loads the cached version.
4. **Compiled dump.** `zcompile` produces a `.zwc` binary of the completion dump for faster loading.
5. **Cached brew prefix.** `brew --prefix` output is written to a file and reused, avoiding a slow subprocess on every login.
6. **Cached completions.** CLI tool completions (gh, docker, kubectl, etc.) are generated once and cached until the binary changes.
7. **PATH cleanup.** Non-existent directories are stripped from PATH via the `(N-/)` glob qualifier, so the shell does not search dead paths.
8. **Async autosuggestions.** `ZSH_AUTOSUGGEST_USE_ASYNC=1` prevents suggestion lookups from blocking input.

To profile startup time:

```bash
# Quick timing
time zsh -i -c exit

# Detailed profiling (uncomment zprof lines in .zshrc)
# Line 6:  zmodload zsh/zprof
# Line 225: zprof
```

## Customization

### Local overrides

Create `$ZDOTDIR/.zshrc.local` (i.e., `~/.config/zsh/.zshrc.local`) for machine-specific settings. This file is sourced last and is not version-controlled.

### Adding aliases or functions

Edit `zsh/aliases.zsh` or `zsh/functions.zsh` directly. Follow the existing pattern of gating on `command -v` for any alias that depends on an optional tool. After editing, run `exec zsh` or use the `reload` alias.

### Adding a plugin

1. Clone the plugin repo into `zsh/plugins/`.
2. Add a `source` line in `.zshrc` with a path check. Place it before zsh-syntax-highlighting, which must remain last.
3. If the plugin provides completions, add its path to `fpath` before the `compinit` call.

### Adding tool completions

Use the `_cache_completion` helper in `completions.zsh`:

```zsh
_cache_completion <name> <binary> <generation-command...>
```

For example:

```zsh
_cache_completion ripgrep rg rg --generate complete-zsh
```

The completion is generated once and regenerated automatically when the binary is updated.

### Changing the prompt

The prompt is managed by Starship. Edit `~/.config/starship.toml` (or wherever your Starship config lives). No changes to the Zsh config are needed.
