# Plan 005: Cut brew subshells from zsh startup and fix HOMEBREW_PREFIX in non-login shells

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat c38554e..HEAD -- zsh/.zshrc zsh/.zprofile docs/zsh.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (independent of 001–004; listed last only because the others are higher leverage)
- **Category**: perf
- **Planned at**: commit `c38554e`, 2026-06-12

## Why this matters

The README claims sub-100ms zsh startup, but every interactive shell currently pays for **two** `$(brew --prefix)` subshells (~50ms+ each on macOS) just to load the `zsh-history-substring-search` plugin. Meanwhile `.zprofile` writes a `brew --prefix` cache file that **nothing ever reads** (confirmed: the only references in the repo are the writer itself and a doc paragraph describing the cache as if it worked), and in non-login interactive shells (`zsh` from another shell, some editor terminals) `HOMEBREW_PREFIX` is never set, so the fzf keybindings/completion block silently does nothing. One static prefix-detection block fixes all three: no subshells, no dead cache, fzf works in every interactive shell.

## Current state

- `zsh/.zshrc` — interactive config:
  - Lines 126–141, fzf block, depends on `$HOMEBREW_PREFIX` with no fallback:

```zsh
# zsh/.zshrc:126-133
if command -v fzf &> /dev/null; then
    # Load FZF key bindings and completion
    if [[ -f "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ]]; then
        source "$HOMEBREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
    fi
    if [[ -f "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh" ]]; then
        source "$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh"
    fi
```

  - Lines 161–170, the two `brew --prefix` subshells:

```zsh
# zsh/.zshrc:161-164
# zsh-history-substring-search
if [[ -f "$(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
    source "$(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
    bindkey -e
```

- `zsh/.zprofile` — login-shell config:
  - Lines 5–14 set `HOMEBREW_PREFIX` for login shells via `brew shellenv` (keep as-is):

```zsh
# zsh/.zprofile:5-14
if [[ -z "$HOMEBREW_PREFIX" ]]; then
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    elif [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi
```

  - Lines 111–117, the dead cache (written, never read anywhere in the repo):

```zsh
# zsh/.zprofile:111-117
# Performance: Cache expensive commands
if [[ ! -f "$XDG_CACHE_HOME/zsh/brew_prefix" ]] || [[ "$XDG_CACHE_HOME/zsh/brew_prefix" -ot "$(command -v brew)" ]]; then
    if command -v brew &> /dev/null; then
        mkdir -p "$XDG_CACHE_HOME/zsh"
        brew --prefix > "$XDG_CACHE_HOME/zsh/brew_prefix" 2>/dev/null
    fi
fi
```

- `docs/zsh.md:75` — describes the dead cache as functional:

```markdown
**Brew prefix cache.** Caches the output of `brew --prefix` to `$XDG_CACHE_HOME/zsh/brew_prefix`, invalidating only when the brew binary changes. This avoids a slow subprocess call on every login.
```

- Brew prefix locations are fixed and known (same table used by `.zprofile` and `docs/install.md`): macOS Apple silicon `/opt/homebrew`, macOS Intel `/usr/local`, Linux/WSL `/home/linuxbrew/.linuxbrew`. This is why a static check needs no subshell.
- Repo conventions: tool blocks gate on `command -v` (see `zsh/aliases.zsh:13`, `zsh/.zshrc:121`); comments are sentence-style above the block they describe.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Zsh syntax check | `zsh -n zsh/.zshrc && zsh -n zsh/.zprofile` | exit 0 |
| Interactive smoke | `zsh -i -c 'echo started_ok'` | prints `started_ok`, exit 0 |
| Non-login prefix check | `zsh -i -c 'printf "%s\n" "${HOMEBREW_PREFIX:-UNSET}"'` | prints a brew prefix path, not `UNSET` (on any machine with Homebrew) |
| No subshells remain | `grep -rn 'brew --prefix' zsh/` | no matches |
| Dead cache gone | `grep -rn 'brew_prefix' zsh/ docs/` | no matches |
| Startup timing (informational) | `hyperfine --warmup 3 'zsh -i -c exit'` (or `time zsh -i -c exit` ×3) | record before/after mean |

## Scope

**In scope** (the only files you should modify):
- `zsh/.zshrc`
- `zsh/.zprofile` (deletion of lines 111–117 only)
- `docs/zsh.md` (the "Brew prefix cache" paragraph only)

**Out of scope** (do NOT touch, even though they look related):
- `.zprofile` lines 5–14 (`brew shellenv` for login shells) — it sets PATH/MANPATH beyond the prefix; leave it.
- `.zprofile`'s ssh-agent / `ssh-add` / `mise where java` / git-config-check blocks — known startup costs, but tracked separately as backlog F6; mixing them in here muddies review.
- `zsh/.zshenv` — including the `GPG_TTY=$(tty)` subshell there (backlog F6).
- `install.sh`, `tests/` — no install-time behavior changes here.

## Git workflow

- Branch: `advisor/005-zsh-startup-homebrew-prefix`
- Commit style: conventional commits. Suggested: `perf(zsh): static HOMEBREW_PREFIX detection, drop brew subshells and dead cache`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 0: Record the baseline timing

Run the timing command from the table and save the mean somewhere you can quote in your final report.

### Step 1: Add static HOMEBREW_PREFIX detection to .zshrc

In `zsh/.zshrc`, directly under the comment `# Initialize modern tools (lazy loading where possible)` (currently line 119) and **before** the starship block, insert:

```zsh
# HOMEBREW_PREFIX is exported by .zprofile in login shells; derive it statically
# (no subshell) for non-login interactive shells so brew-installed plugins load.
if [[ -z "${HOMEBREW_PREFIX:-}" ]]; then
    if [[ -d /opt/homebrew/bin ]]; then
        export HOMEBREW_PREFIX=/opt/homebrew
    elif [[ -d /home/linuxbrew/.linuxbrew/bin ]]; then
        export HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew
    elif [[ -x /usr/local/bin/brew ]]; then
        export HOMEBREW_PREFIX=/usr/local
    fi
fi
```

**Verify**: `zsh -n zsh/.zshrc` → exit 0.

### Step 2: Replace the brew --prefix subshells

Replace the `zsh-history-substring-search` block opening (lines 161–163 region) so both occurrences of `$(brew --prefix)` use the variable, guarded against it being unset:

```zsh
# zsh-history-substring-search
if [[ -n "${HOMEBREW_PREFIX:-}" && -f "$HOMEBREW_PREFIX/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
    source "$HOMEBREW_PREFIX/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
```

Leave the `bindkey` lines and the closing `fi` of that block untouched.

**Verify**: `grep -rn 'brew --prefix' zsh/` → no matches; `zsh -n zsh/.zshrc` → exit 0.

### Step 3: Delete the dead cache block from .zprofile

Delete lines 111–117 of `zsh/.zprofile` (the `# Performance: Cache expensive commands` block excerpted above), including its comment line.

**Verify**: `grep -n 'brew_prefix' zsh/.zprofile` → no matches; `zsh -n zsh/.zprofile` → exit 0.

### Step 4: Correct docs/zsh.md

Replace the "Brew prefix cache" paragraph (`docs/zsh.md:75`) with:

```markdown
**Homebrew prefix.** Login shells get `HOMEBREW_PREFIX` from `brew shellenv` in `.zprofile`. Non-login interactive shells derive it in `.zshrc` from the standard install locations (`/opt/homebrew`, `/usr/local`, `/home/linuxbrew/.linuxbrew`) without spawning a subprocess, so brew-installed plugins (fzf bindings, history-substring-search) load in every interactive shell.
```

**Verify**: `grep -rn 'brew_prefix' docs/` → no matches.

### Step 5: Smoke-test and measure

1. `zsh -i -c 'echo started_ok'` → `started_ok`.
2. `zsh -i -c 'printf "%s\n" "${HOMEBREW_PREFIX:-UNSET}"'` → a real path (e.g. `/opt/homebrew`).
3. On macOS with the plugin installed: `zsh -i -c 'whence history-substring-search-up'` → prints `history-substring-search-up` (widget function exists, proving the plugin still loads via the new path).
4. Re-run the Step 0 timing command; the mean should be ≥ ~80ms faster on a machine where the plugin block previously ran two brew subshells (report the numbers either way — machine variance is expected; a regression is a STOP).

## Test plan

No test files in this repo cover shell startup; verification is the command gates above. The Docker CI test in fast mode does not start interactive zsh, so CI cannot regress or validate this — the local smoke checks in Step 5 are the authoritative gate. (Adding `zsh -i` startup checks to the Docker full mode is backlog F9 territory.)

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `zsh -n zsh/.zshrc` and `zsh -n zsh/.zprofile` exit 0
- [ ] `grep -rn 'brew --prefix' zsh/` → no matches
- [ ] `grep -rn 'brew_prefix' zsh/ docs/` → no matches
- [ ] `zsh -i -c 'echo started_ok'` prints `started_ok`
- [ ] `zsh -i -c 'printf "%s\n" "${HOMEBREW_PREFIX:-UNSET}"'` prints a brew prefix path
- [ ] `git status --porcelain` shows changes only in `zsh/.zshrc`, `zsh/.zprofile`, `docs/zsh.md`
- [ ] Before/after timing numbers recorded in your completion report
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The excerpts in "Current state" don't match the live files (drift since `c38554e`).
- `zsh -i -c ...` fails or hangs after your edits — revert and report rather than debugging unrelated startup issues.
- `whence history-substring-search-up` stops resolving on a machine where it resolved before this change (plugin path assumption wrong for this brew layout).
- You are tempted to also remove the ssh-agent / `mise where java` / GPG_TTY costs — out of scope (backlog F6).

## Maintenance notes

- The static prefix list must stay in sync with `.zprofile:5-14` and the table in `docs/install.md` — three places now name the same three locations. If Homebrew ever changes default prefixes, all three change together.
- Reviewer should scrutinize: the Intel-macOS branch (`/usr/local/bin/brew` check, prefix `/usr/local`) — the only branch not exercised by the maintainer's Apple-silicon machine or Linux CI.
- Deferred: lazy-loading zoxide/starship init, `.zprofile` per-login subprocess sprawl (orphan `ssh-agent` spawns, `mise where java`, git-config check), and `GPG_TTY=$(tty)` in `.zshenv` — all tracked as backlog F6 in `plans/README.md`.
