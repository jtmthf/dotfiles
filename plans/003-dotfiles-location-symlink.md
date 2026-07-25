# Plan 003: Make the install work from any clone location (installer-managed ~/.dotfiles symlink)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat c38554e..HEAD -- install.sh tests/verify.sh docs/install.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. (Plans 001/002 legitimately touch
> `tests/verify.sh` and `install.sh` — those specific diffs are expected.)

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-fix-ci-settings-merge-assertion.md (green test baseline); execute after 002 to avoid `install.sh` merge conflicts
- **Category**: bug
- **Planned at**: commit `c38554e`, 2026-06-12

## Why this matters

`install.sh` self-detects its own location (`DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, line 24) and creates symlinks that point at the real checkout — so the *installer* works from anywhere. But the runtime zsh config hardcodes `~/.dotfiles`: `.zshrc` loads `aliases.zsh`/`functions.zsh`/plugins from `$HOME/.dotfiles` (zsh/.zshrc:80), `.zshenv` exports `DOTFILES="$HOME/.dotfiles"` (zsh/.zshenv:81), `functions.zsh` updates plugins under it (line 261), and `completions.zsh` adds it to `fpath` (line 46). On the maintainer's machine this only works because of a **hand-made** `~/.dotfiles → ~/Projects/open-source/dotfiles` symlink the installer never creates. Worse, `docs/install.md:15` tells new users to clone to `~/dotfiles` (no dot) — following the official instructions yields a shell with no aliases, no functions, and no plugins, failing only with a startup warning. Fix: the installer guarantees `~/.dotfiles` points at the checkout.

## Current state

- `install.sh`:
  - Line 24: `DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` — self-detected checkout path.
  - `run()` helper (lines 40–46) wraps state-changing commands for `--dry-run`.
  - `main()` (lines 416–438) calls, in order: `install_homebrew`, `install_packages`, `setup_zsh_plugins`, `create_symlinks`, `setup_tmux`, `setup_claude`, `setup_playwright_cli`, `setup_zed`, `setup_gh`, `setup_crawl4ai`, then `setup_colima` on macOS.
  - `rollback()` (lines 364–413) removes installer-created symlinks with `rm -f`, e.g. line 376: `rm -f "$HOME/.config/zsh/.zshenv" ...`.
  - Logging convention: `log_info` / `log_success` / `log_error` from `lib/logging.sh`; every `setup_*` function starts with `log_info "Setting up ..."` and ends with `log_success "... complete"`.
- `zsh/.zshrc:80` — `DOTFILES_DIR="$HOME/.dotfiles"` (then `load_config "$DOTFILES_DIR/zsh/aliases.zsh"` etc.). **Do not modify** — the symlink approach makes this valid.
- `zsh/.zshenv:81` — `export DOTFILES="$HOME/.dotfiles"`. **Do not modify.**
- `tests/verify.sh` — after plan 001, contains `assert_*` helpers and a `--- Bootstrap ---` section starting at the `echo "--- Bootstrap ---"` line. In the test container, the repo is copied to `/home/linuxbrew/.dotfiles`, i.e. `~/.dotfiles` *is* the real checkout there (tests/Dockerfile:6: `COPY --chown=linuxbrew:linuxbrew . /home/linuxbrew/.dotfiles`).
- `docs/install.md:12-18`:

```markdown
## Quick Start

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
./install.sh
```
```

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Bash syntax check | `bash -n install.sh && bash -n tests/verify.sh` | exit 0 |
| Dry-run | `./install.sh --dry-run` | exit 0; logs `[DRY RUN]` lines; creates nothing |
| Full test (what CI runs) | `DOTFILES_TEST_MODE=fast bash scripts/test-docker.sh` | exit 0, `0 failed` in both verify scripts |

## Scope

**In scope** (the only files you should modify):
- `install.sh`
- `tests/verify.sh`
- `docs/install.md` (Quick Start section only)

**Out of scope** (do NOT touch, even though they look related):
- `zsh/.zshrc`, `zsh/.zshenv`, `zsh/functions.zsh`, `zsh/completions.zsh` — their hardcoded `~/.dotfiles` references become *valid* with this change; rewriting them to derive the path dynamically is more invasive and is intentionally not this plan.
- `README.md` — its Quick Start already says `~/.dotfiles`; remaining README problems are backlog item F10.
- `tests/Dockerfile` — the in-container layout already matches the target state.

## Git workflow

- Branch: `advisor/003-dotfiles-location-symlink`
- Commit style: conventional commits. Suggested: `fix(install): guarantee ~/.dotfiles points at the checkout`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add setup_dotfiles_link() to install.sh

Add this function after `detect_os`/argument parsing region — place it directly above `install_homebrew()` (currently line 84–85):

```bash
# Guarantee ~/.dotfiles points at this checkout. The zsh config (aliases,
# functions, plugin loading) resolves the repo via ~/.dotfiles, so the repo
# may be cloned anywhere as long as this link exists.
setup_dotfiles_link() {
    if [[ "$DOTFILES_DIR" == "$HOME/.dotfiles" ]]; then
        return
    fi
    if [[ -L "$HOME/.dotfiles" ]]; then
        if [[ "$(readlink "$HOME/.dotfiles")" == "$DOTFILES_DIR" ]]; then
            log_info "~/.dotfiles already links to $DOTFILES_DIR"
            return
        fi
        run ln -sfn "$DOTFILES_DIR" "$HOME/.dotfiles"
    elif [[ -e "$HOME/.dotfiles" ]]; then
        log_error "~/.dotfiles exists and is not a symlink. Move it aside or clone the repo there directly."
        exit 1
    else
        run ln -s "$DOTFILES_DIR" "$HOME/.dotfiles"
    fi
    log_success "Linked ~/.dotfiles -> $DOTFILES_DIR"
}
```

Then add `setup_dotfiles_link` as the **first** call inside `main()` (before `install_homebrew`) — the zsh config and `update-all` depend on the link, so it must exist even if a later step fails.

**Verify**: `bash -n install.sh` → exit 0; `grep -n "setup_dotfiles_link" install.sh` → exactly 2 matches (definition + call in main).

### Step 2: Remove the link on rollback

In `rollback()`, after the existing block of `rm -f` symlink removals (the lines removing `~/.config/...` links, currently ending around line 387 with `rm -f "$HOME/.config/git/config"`), add:

```bash
    [[ -L "$HOME/.dotfiles" ]] && rm -f "$HOME/.dotfiles"
```

(Guarded by `-L` so a real directory at that path can never be touched.)

**Verify**: `bash -n install.sh` → exit 0.

### Step 3: Assert the link in verify.sh

In `tests/verify.sh`, in the `--- Bootstrap ---` section (after the three `~/.zshenv` assertions), add:

```bash
if [[ "$(readlink -f "$HOME/.dotfiles")" == "$(readlink -f "$DOTFILES_DIR")" ]]; then
    pass "~/.dotfiles resolves to the dotfiles checkout"
else
    fail "~/.dotfiles does not resolve to $DOTFILES_DIR"
fi
```

This passes in both layouts: container (`~/.dotfiles` *is* the checkout) and a real machine (symlink resolves to the checkout).

**Verify**: `bash -n tests/verify.sh` → exit 0.

### Step 4: Fix the Quick Start in docs/install.md

Replace the Quick Start code block (`docs/install.md:14-18`) with:

```markdown
```bash
git clone https://github.com/jtmthf/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

The repo can live anywhere — if it is cloned somewhere other than
`~/.dotfiles`, the installer creates a `~/.dotfiles` symlink pointing at the
checkout (the zsh configuration resolves the repo through that path).
```

**Verify**: `grep -n "~/dotfiles" docs/install.md` → no matches (the dot-less path is gone).

### Step 5: Dry-run and full test

1. `./install.sh --dry-run` → exit 0. (On a machine where `~/.dotfiles` already links to the checkout, expect the `already links` info line; in a fresh layout, expect a `[DRY RUN] ln -s ...` line.)
2. `DOTFILES_TEST_MODE=fast bash scripts/test-docker.sh` → exit 0, `0 failed` in both verify scripts.

## Test plan

- The new `verify.sh` assertion (Step 3) covers the identity case in CI.
- The symlink-creation branch is exercised by the dry-run check in Step 5 when run from a non-`~/.dotfiles` checkout (which is the layout on the maintainer's machine: `~/Projects/open-source/dotfiles`).
- No new test file; pattern matched: existing inline `if/pass/fail` blocks in `tests/verify.sh` (e.g. the `zsh sources ~/.zshenv` check at lines 117–121).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `bash -n install.sh` and `bash -n tests/verify.sh` exit 0
- [ ] `grep -c "setup_dotfiles_link" install.sh` outputs `2`
- [ ] `grep -n '\-L "$HOME/.dotfiles"' install.sh` shows the guarded rollback removal
- [ ] `grep -n "~/dotfiles" docs/install.md` outputs nothing
- [ ] `./install.sh --dry-run` exits 0
- [ ] `DOTFILES_TEST_MODE=fast bash scripts/test-docker.sh` exits 0
- [ ] `git status --porcelain` shows changes only in `install.sh`, `tests/verify.sh`, `docs/install.md`
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `install.sh:24` no longer self-detects `DOTFILES_DIR` as excerpted (the whole approach assumes it).
- `~/.dotfiles` on the executing machine is a real directory that is **not** this checkout — do not move or delete it; report. (The `exit 1` branch in Step 1 is for end users; an executor hitting it during verification should report instead.)
- The Docker test fails on the new Step 3 assertion — the container layout assumption (repo at `/home/linuxbrew/.dotfiles`) has changed.
- You are tempted to rewrite the hardcoded paths in `zsh/*` files — explicitly out of scope.

## Maintenance notes

- The contract is now: **`~/.dotfiles` always resolves to the checkout**. Anything new in `zsh/` may rely on `$DOTFILES` / `~/.dotfiles`; anything in `install.sh` should keep using `$DOTFILES_DIR`.
- Rollback removes the symlink even if the user created it manually before ever running the installer — acceptable (rollback means "undo dotfiles"), but worth remembering if a user reports a missing link after rollback.
- Reviewer should scrutinize: `ln -sfn` (the `-n` matters when replacing an existing symlink to a directory), and that `setup_dotfiles_link` runs before anything sources zsh config.
- Deferred: deriving the repo path dynamically in `.zshrc` (removing the hardcode entirely) — rejected as higher-risk zsh-fu for no practical gain once the link is installer-managed.
