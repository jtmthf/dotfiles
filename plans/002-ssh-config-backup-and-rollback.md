# Plan 002: Stop --rollback from destroying the user's ~/.ssh/config

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat c38554e..HEAD -- install.sh tests/Dockerfile tests/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. (Plan 001 legitimately changes
> `tests/verify.sh` and `tests/Dockerfile` — those specific diffs are expected.)

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW (changes make a destructive path strictly safer)
- **Depends on**: plans/001-fix-ci-settings-merge-assertion.md (green baseline + jq in test image)
- **Category**: security/bug (data loss)
- **Planned at**: commit `c38554e`, 2026-06-12

## Why this matters

`install.sh --rollback` runs `rm -f "$HOME/.ssh/config"` and then restores it only from `$latest_backup/ssh_config` — **a file the installer never creates**. The installer deliberately keeps `~/.ssh/config` as a real file (so 1Password and other tools can append host entries) and *prepends* an `Include` line to whatever the user already has, but it never backs the original up. Result: running `--rollback` permanently deletes every host entry the user accumulated. `docs/install.md` even claims rollback "Restores `~/.ssh/config` … from the backup directory if they were replaced" — currently false. This plan makes install back the file up, makes rollback restore it (or, when no backup exists, surgically strip only the `Include` line), and adds a Docker test that proves the round-trip.

## Current state

- `install.sh` — installer; relevant regions:
  - `create_symlinks()` SSH block, lines 268–294. The prepend branch modifies the user's existing file **without backing it up**:

```bash
# install.sh:272-287
        local ssh_include="Include $DOTFILES_DIR/config/ssh/config"
        if [[ -L "$HOME/.ssh/config" ]]; then
            rm -f "$HOME/.ssh/config"
        fi
        if [[ ! -f "$HOME/.ssh/config" ]]; then
            printf '%s\n' "$ssh_include" > "$HOME/.ssh/config"
            chmod 600 "$HOME/.ssh/config"
        elif ! grep -qF "$ssh_include" "$HOME/.ssh/config"; then
            # Real file exists (e.g. has 1Password entries) — prepend Include, preserve content
            local tmp
            tmp=$(mktemp)
            { printf '%s\n' "$ssh_include"; cat "$HOME/.ssh/config"; } > "$tmp"
            mv "$tmp" "$HOME/.ssh/config"
            chmod 600 "$HOME/.ssh/config"
        fi
```

  - `rollback()`, lines 364–413. The deletion (line 386) and the restore that can never fire (line 399):

```bash
# install.sh:386
    rm -f "$HOME/.ssh/config" "$HOME/.ssh/config.local"
```

```bash
# install.sh:399
    [[ -f "$latest_backup/ssh_config" ]] && { log_info "Restoring .ssh/config"; cp "$latest_backup/ssh_config" "$HOME/.ssh/config"; }
```

  - `BACKUP_DIR` is `~/.dotfiles_backup_<timestamp>` (line 25), created at line 53 for non-dry-run; the whole SSH block lives inside the non-dry-run `else` branch of `create_symlinks`, so `BACKUP_DIR` always exists when it runs.
  - The repo's convention for backup filenames in `BACKUP_DIR` is flat snake_case names: `ssh_config`, `git_config`, `zed_settings.json`, `gh_config.yml` (see rollback lines 399–409). `ssh_config` is the name rollback already expects.
- `tests/Dockerfile` — after plan 001, line 4 installs `zsh git curl jq`; line 13 is:

```dockerfile
CMD ["bash", "-c", "bash install.sh && bash tests/verify.sh"]
```

- `tests/verify.sh` — assertion script with `pass`/`fail` helpers (lines 14–15) and `assert_*` functions (lines 17–66). New test file should copy this structure.
- `scripts/test-docker.sh` — builds `tests/Dockerfile` and runs the container; `DOTFILES_TEST_MODE=fast` exports `SKIP_BREW_BUNDLE=1` into the container, which also covers any *re-run* of `install.sh` inside it.
- `docs/install.md:147` — "Restores `~/.ssh/config` and `~/.config/git/config` from the backup directory if they were replaced." (Becomes true for ssh after this plan; the git_config path already works.)

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Bash syntax check | `bash -n install.sh && bash -n tests/verify-rollback.sh` | exit 0 |
| Full test (what CI runs) | `DOTFILES_TEST_MODE=fast bash scripts/test-docker.sh` | exit 0; verify.sh `0 failed` AND verify-rollback.sh `0 failed` |
| Dry-run sanity | `./install.sh --dry-run` | exit 0; no filesystem changes |

## Scope

**In scope** (the only files you should modify):
- `install.sh` (only the two regions excerpted above)
- `tests/verify-rollback.sh` (create)
- `tests/Dockerfile` (CMD line only)

**Out of scope** (do NOT touch, even though they look related):
- `config/ssh/config` — the SSH config content itself.
- The other rollback restore paths (`git_config`, `zed_settings.json`, `opencode`, claude files) — they have their own backup logic; consolidation is a separate backlog item (F8).
- `docs/install.md` — its rollback claim becomes true after this change; no edit needed.
- `scripts/test-docker.sh`, `.github/workflows/test.yml`.

## Git workflow

- Branch: `advisor/002-ssh-config-backup-and-rollback`
- Commit style: conventional commits (repo examples: `fix: guard ~/.claude dir creation in rollback, consolidate rm -f`). Suggested: `fix(install): back up ~/.ssh/config before modifying; make rollback restore it`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Back up the user's real ~/.ssh/config before prepending

In `install.sh` `create_symlinks()`, inside the `elif ! grep -qF "$ssh_include" ...` branch (currently line 279), add a `cp` **as the first statement of the branch**, before the existing `local tmp`:

```bash
        elif ! grep -qF "$ssh_include" "$HOME/.ssh/config"; then
            # Real file exists (e.g. has 1Password entries) — back it up, prepend Include, preserve content
            cp "$HOME/.ssh/config" "$BACKUP_DIR/ssh_config"
            local tmp
            tmp=$(mktemp)
```

(Use `cp`, not `mv` — the file is still read by the `cat` two lines later.)

**Verify**: `bash -n install.sh` → exit 0; `grep -n 'cp "$HOME/.ssh/config" "$BACKUP_DIR/ssh_config"' install.sh` → one match inside `create_symlinks`.

### Step 2: Make rollback restore-or-strip instead of delete

In `rollback()`, replace line 386 (`rm -f "$HOME/.ssh/config" "$HOME/.ssh/config.local"`) with:

```bash
    rm -f "$HOME/.ssh/config.local"
    local ssh_include="Include $DOTFILES_DIR/config/ssh/config"
    if [[ -f "$latest_backup/ssh_config" ]]; then
        # A pre-install copy exists; the restore loop below puts it back
        rm -f "$HOME/.ssh/config"
    elif [[ -f "$HOME/.ssh/config" ]] && grep -qF "$ssh_include" "$HOME/.ssh/config"; then
        # No backup — surgically remove only the Include line the installer added
        local tmp
        tmp=$(mktemp)
        grep -vF "$ssh_include" "$HOME/.ssh/config" > "$tmp" || true
        mv "$tmp" "$HOME/.ssh/config"
        chmod 600 "$HOME/.ssh/config"
    fi
```

Notes for correctness:
- `$DOTFILES_DIR` is a top-level variable (line 24) and is in scope inside `rollback()`.
- The `|| true` guards the case where the file contains *only* the Include line (grep -v then exits 1 on empty output).
- The existing restore at line 399 stays exactly as is — it now actually fires when a backup exists. Leave it untouched.

**Verify**: `bash -n install.sh` → exit 0; `grep -c 'rm -f "$HOME/.ssh/config" "$HOME/.ssh/config.local"' install.sh` → `0`.

### Step 3: Create tests/verify-rollback.sh

Create `tests/verify-rollback.sh` with exactly this content (modeled on `tests/verify.sh`'s helper style):

```bash
#!/usr/bin/env bash
# Rollback verification — runs INSIDE the Docker container, after install.sh + verify.sh.
# Proves the ssh-config backup/restore round-trip:
#   seed real config -> install (prepends Include, backs up) -> rollback (restores original).

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
PASS=0
FAIL=0

green='\033[0;32m'
red='\033[0;31m'
reset='\033[0m'

pass() { echo -e "${green}PASS${reset}  $1"; (( PASS++ )) || true; }
fail() { echo -e "${red}FAIL${reset}  $1"; (( FAIL++ )) || true; }

MARKER="Host rollback-canary"
SSH_INCLUDE="Include $DOTFILES_DIR/config/ssh/config"

echo "=== Rollback verification (ssh config round-trip) ==="

# 1. Seed a real user ssh config containing a canary entry and no Include
rm -f "$HOME/.ssh/config"
printf '%s\n  HostName example.com\n' "$MARKER" > "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

# 2. Re-run the installer (idempotent second run; SKIP_BREW_BUNDLE is inherited in fast mode)
bash "$DOTFILES_DIR/install.sh"

if grep -qF "$SSH_INCLUDE" "$HOME/.ssh/config"; then
    pass "install prepended Include to existing config"
else
    fail "install did not add Include line"
fi
if grep -qF "$MARKER" "$HOME/.ssh/config"; then
    pass "install preserved existing content"
else
    fail "install lost existing config content"
fi

latest_backup=$(ls -dt "$HOME"/.dotfiles_backup_* | head -1)
if [[ -f "$latest_backup/ssh_config" ]] && grep -qF "$MARKER" "$latest_backup/ssh_config"; then
    pass "install backed up pre-modification ssh config"
else
    fail "no ssh_config backup found in $latest_backup"
fi

# 3. Roll back
bash "$DOTFILES_DIR/install.sh" --rollback

if [[ -f "$HOME/.ssh/config" ]]; then
    pass "ssh config still exists after rollback"
else
    fail "rollback deleted ~/.ssh/config"
fi
if grep -qF "$MARKER" "$HOME/.ssh/config" 2>/dev/null; then
    pass "rollback restored original content"
else
    fail "rollback lost the canary entry"
fi
if ! grep -qF "$SSH_INCLUDE" "$HOME/.ssh/config" 2>/dev/null; then
    pass "rollback removed the Include line"
else
    fail "Include line still present after rollback"
fi

echo ""
echo "=== Rollback results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]
```

**Verify**: `bash -n tests/verify-rollback.sh` → exit 0.

### Step 4: Chain the new script into the container CMD

In `tests/Dockerfile`, change the CMD line to:

```dockerfile
CMD ["bash", "-c", "bash install.sh && bash tests/verify.sh && bash tests/verify-rollback.sh"]
```

**Verify**: `grep -n "verify-rollback.sh" tests/Dockerfile` → one match.

### Step 5: Run the full Docker test

`DOTFILES_TEST_MODE=fast bash scripts/test-docker.sh`

**Verify**: exit 0. Output contains `=== Results: N passed, 0 failed ===` (verify.sh) followed by `=== Rollback results: 6 passed, 0 failed ===`.

## Test plan

Covered by Step 3: the new `tests/verify-rollback.sh` asserts (1) Include prepended, (2) existing content preserved, (3) backup file created, (4) file survives rollback, (5) original content restored, (6) Include removed. Structural pattern: `tests/verify.sh` helpers. Run via `scripts/test-docker.sh` (Step 5). Note the rollback run intentionally tears down the install inside the container — that is why this script runs **last** in the CMD chain.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `bash -n install.sh` and `bash -n tests/verify-rollback.sh` exit 0
- [ ] `grep -c 'rm -f "$HOME/.ssh/config" "$HOME/.ssh/config.local"' install.sh` outputs `0`
- [ ] `grep -n 'BACKUP_DIR/ssh_config' install.sh` shows the new `cp` in `create_symlinks`
- [ ] `DOTFILES_TEST_MODE=fast bash scripts/test-docker.sh` exits 0, including `Rollback results: 6 passed, 0 failed`
- [ ] `./install.sh --dry-run` exits 0 (dry-run path untouched and still clean)
- [ ] `git status --porcelain` shows changes only in `install.sh`, `tests/verify-rollback.sh`, `tests/Dockerfile`
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The SSH block or rollback excerpts in "Current state" don't match the live code (drift since `c38554e`).
- Plan 001 has not been executed (check: `grep -c "settings.json symlink" tests/verify.sh` must be `0`) — running this plan's Docker test on top of a red baseline makes the results unreadable. Report and wait.
- The second `install.sh` run inside the container fails for a reason unrelated to ssh config (e.g. plugin clone, brew). That's an idempotency bug outside this plan's scope.
- Docker is unavailable in your environment.
- You find yourself wanting to refactor the other rollback restore paths — that is backlog item F8, not this plan.

## Maintenance notes

- The rollback semantics changed: with no backup present, rollback now *edits* `~/.ssh/config` (removes the Include line) instead of deleting the file. `docs/install.md`'s rollback section is now accurate; if rollback behavior changes again, update that doc.
- The backup name `ssh_config` is load-bearing: `rollback()` line 399 looks for exactly that name. If the flat-name convention in `BACKUP_DIR` is ever restructured (backlog F8/D1), both sides must move together.
- Reviewer should scrutinize: the `grep -vF || true` empty-file edge case, and that `cp` (not `mv`) is used in Step 1.
- Deferred: idempotency coverage for a second `install.sh` run is *implicitly* added here (the test re-runs the installer); a dedicated idempotency test remains backlog F9.
