# Plan 001: Make CI green again — verify the merged settings.json instead of asserting a symlink

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat c38554e..HEAD -- tests/verify.sh tests/Dockerfile install.sh`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `c38554e`, 2026-06-12

## Why this matters

CI on `main` has been red since 2026-05-11 (5 consecutive failed runs). Commit `cf610b9` changed the installer to **jq-merge** `config/claude/settings.json` into `~/.claude/settings.json` (a real file, live-wins semantics), but `tests/verify.sh` still asserts that path is a **symlink**. The failing CI log shows exactly one failure: `FAIL claude/settings.json symlink — not a symlink: /home/linuxbrew/.claude/settings.json`. Until this is fixed, the repo has no working verification baseline — every other change lands unverified, and every other plan in `plans/` relies on this test being green.

## Current state

- `tests/verify.sh` — assertion script run inside the Docker test container after `install.sh`. Lines 82–92 assert symlinks; line 90 is the stale one:

```bash
# tests/verify.sh:88-92
assert_symlink "git/config symlink"           "$HOME/.config/git/config"            "$DOTFILES_DIR/config/git/config"
assert_symlink "git/ignore symlink"           "$HOME/.config/git/ignore"            "$DOTFILES_DIR/config/git/ignore"
assert_symlink "claude/settings.json symlink" "$HOME/.claude/settings.json"         "$DOTFILES_DIR/config/claude/settings.json"
assert_symlink "claude/CLAUDE.md symlink"     "$HOME/.claude/CLAUDE.md"             "$DOTFILES_DIR/config/claude/CLAUDE.md"
assert_symlink "claude/TMUX.md symlink"       "$HOME/.claude/TMUX.md"               "$DOTFILES_DIR/config/claude/TMUX.md"
```

- `install.sh` — `merge_claude_settings()` (lines 169–204) jq-merges the repo file into the live file (deep object merge, live wins; `.permissions.allow`/`.permissions.deny` arrays unioned). It hard-requires `jq` (lines 173–176, `return 1` if missing, which aborts the install under `set -euo pipefail`). `setup_claude()` (lines 207–220) calls the merge, then symlinks `CLAUDE.md`, `TMUX.md`, `SEARCH.md`, and `WEB.md` into `~/.claude/`. Note: `SEARCH.md` and `WEB.md` are linked by the installer but never asserted by `verify.sh` — this plan adds those assertions.
- `config/claude/settings.json` — the repo baseline. Top-level keys: `env`, `permissions` (with `allow`/`deny` arrays), `hooks`, `enabledPlugins`, `extraKnownMarketplaces`, `effortLevel`, `teammateMode`, `mcpServers`. The `permissions.allow` array contains the entry `"Bash(rg:*)"` — used below as a stable merge marker.
- `tests/Dockerfile` — Ubuntu-based Homebrew image; installs only `zsh git curl` via apt:

```dockerfile
# tests/Dockerfile:4
RUN apt-get update && apt-get install -y zsh git curl && rm -rf /var/lib/apt/lists/*
```

```dockerfile
# tests/Dockerfile:13
CMD ["bash", "-c", "bash install.sh && bash tests/verify.sh"]
```

- `scripts/test-docker.sh` — builds the image and runs it; `DOTFILES_TEST_MODE=fast` sets `SKIP_BREW_BUNDLE=1` so `brew bundle` is skipped (this is what CI runs).
- `.github/workflows/test.yml` — single job, `runs-on: ubuntu-latest`, runs `bash scripts/test-docker.sh` with `DOTFILES_TEST_MODE: fast`.
- Convention: `verify.sh` uses small `assert_*` helper functions (lines 17–66) that call `pass`/`fail` counters. New assertions must follow that pattern.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Bash syntax check | `bash -n tests/verify.sh` | exit 0, no output |
| Full test (what CI runs) | `DOTFILES_TEST_MODE=fast bash scripts/test-docker.sh` | exits 0; last line `=== Results: N passed, 0 failed ===` |

The Docker test takes a few minutes (image build + install). Requires a working Docker daemon.

## Scope

**In scope** (the only files you should modify):
- `tests/verify.sh`
- `tests/Dockerfile`

**Out of scope** (do NOT touch, even though they look related):
- `install.sh` — the merge logic is correct; the *test* is wrong. Do not "fix" the installer to produce a symlink.
- `config/claude/settings.json` — content changes would alter the user's live merged settings on next install.
- `.github/workflows/test.yml` — no workflow change needed; plan 004 owns workflow edits.

## Git workflow

- Branch: `advisor/001-fix-ci-settings-merge-assertion`
- Commit style: conventional commits, matching repo history (e.g. `fix: use mise shims in non-login interactive shells`). Suggested: `fix(tests): assert merged settings.json instead of symlink`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Make jq explicitly available in the test image

In `tests/Dockerfile` line 4, add `jq` to the apt install list:

```dockerfile
RUN apt-get update && apt-get install -y zsh git curl jq && rm -rf /var/lib/apt/lists/*
```

Rationale: `merge_claude_settings()` aborts the whole install if `jq` is missing, and in fast mode `brew bundle` (which would install jq) is skipped. CI currently works only because the base image happens to provide jq; make it explicit.

**Verify**: `grep -n "apt-get install -y zsh git curl jq" tests/Dockerfile` → exactly one match.

### Step 2: Add a jq-based assertion helper to verify.sh

In `tests/verify.sh`, after the existing `assert_cmd` helper (ends line 66), add:

```bash
assert_json_has() {
    local desc="$1" path="$2" filter="$3"
    if jq -e "$filter" "$path" >/dev/null 2>&1; then
        pass "$desc"
    else
        fail "$desc — jq filter '$filter' did not match in $path"
    fi
}
```

**Verify**: `bash -n tests/verify.sh` → exit 0.

### Step 3: Replace the stale symlink assertion with merged-file assertions

Replace line 90 (`assert_symlink "claude/settings.json symlink" ...`) with:

```bash
if [[ -f "$HOME/.claude/settings.json" && ! -L "$HOME/.claude/settings.json" ]]; then
    pass "claude/settings.json is a real merged file"
else
    fail "claude/settings.json missing or is a symlink: $HOME/.claude/settings.json"
fi
assert_json_has "claude/settings.json is valid JSON"            "$HOME/.claude/settings.json" "."
assert_json_has "claude/settings.json contains repo permission" "$HOME/.claude/settings.json" '.permissions.allow | index("Bash(rg:*)")'
```

The marker `"Bash(rg:*)"` exists in `config/claude/settings.json`'s `permissions.allow` and must survive the union merge — if it's absent from the merged file, the merge is broken.

**Verify**: `bash -n tests/verify.sh` → exit 0, and `grep -c "settings.json symlink" tests/verify.sh` → `0`.

### Step 4: Assert the two unasserted Claude symlinks

Immediately after the existing `claude/TMUX.md symlink` assertion (originally line 92), add:

```bash
assert_symlink "claude/SEARCH.md symlink"     "$HOME/.claude/SEARCH.md"             "$DOTFILES_DIR/config/claude/SEARCH.md"
assert_symlink "claude/WEB.md symlink"        "$HOME/.claude/WEB.md"                "$DOTFILES_DIR/config/claude/WEB.md"
```

**Verify**: `bash -n tests/verify.sh` → exit 0.

### Step 5: Run the full Docker test

`DOTFILES_TEST_MODE=fast bash scripts/test-docker.sh`

**Verify**: exit code 0; output ends with `=== Results: N passed, 0 failed ===` (N should be 26: the previous 23 checks, minus 1 replaced, plus 3 settings assertions, plus 2 new symlink assertions — count printed by the script).

## Test plan

This plan *is* test work; no additional tests beyond the assertions added above. The regression being covered: installer produces a merged real file with repo baseline content preserved, and all five `~/.claude/` doc files are linked.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `bash -n tests/verify.sh` exits 0
- [ ] `grep -c "settings.json symlink" tests/verify.sh` outputs `0`
- [ ] `grep -n "jq" tests/Dockerfile` shows jq in the apt-get line
- [ ] `DOTFILES_TEST_MODE=fast bash scripts/test-docker.sh` exits 0 with `0 failed`
- [ ] `git status --porcelain` shows changes only in `tests/verify.sh` and `tests/Dockerfile`
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- `tests/verify.sh:90` does not match the excerpt above (drift since `c38554e`).
- After Step 5, `~/.claude/settings.json` does not exist inside the container at all (failure message says "missing") — that means `merge_claude_settings` is failing for a different reason than the stale assertion, and the fix is in `install.sh`, which is out of scope.
- Docker is unavailable in your environment — report; do not substitute an ad-hoc local simulation of the container.
- The jq merge-marker assertion fails while the file exists and is valid JSON — the merge semantics themselves are broken; that is an `install.sh` bug, out of scope here.

## Maintenance notes

- Any future change to `setup_claude()` in `install.sh` (new linked file, different merge semantics) must update these assertions in the same commit — this exact drift is what kept CI red for a month.
- Reviewer should scrutinize: the merge-marker key `"Bash(rg:*)"`; if it is ever removed from `config/claude/settings.json`, this assertion must move to another stable entry.
- Deferred: testing merge *semantics* in isolation (idempotency, live-wins) — see backlog item F9 in `plans/README.md`.
