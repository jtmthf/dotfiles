# Plan 004: Add a lint gate — shellcheck for bash, `zsh -n` for zsh — and fix what it flags

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat c38554e..HEAD -- .github/workflows/test.yml install.sh lib/ scripts/ tests/ zsh/`
> Plans 001–003 legitimately modify `install.sh`, `tests/`, and the workflow
> is untouched until now. If `.github/workflows/test.yml` differs from the
> excerpt below, STOP.

## Status

- **Priority**: P2
- **Effort**: M (the CI job is small; fixing pre-existing findings is the bulk)
- **Risk**: LOW (lint fixes must be behavior-preserving; anything that isn't gets a directive instead)
- **Depends on**: plans/002-ssh-config-backup-and-rollback.md and plans/003-dotfiles-location-symlink.md (so their `install.sh` edits are linted too, and to avoid churn)
- **Category**: dx
- **Planned at**: commit `c38554e`, 2026-06-12

## Why this matters

The repo is ~1,500 lines of bash and zsh that mutate `$HOME`, with no lint of any kind: CI runs only a Docker smoke test. `install.sh:5` carries a `# shellcheck source=lib/logging.sh` directive — signaling shellcheck was intended — but nothing ever runs it, so quoting and globbing bugs ship silently into an installer that moves and deletes files. This plan adds a fast CI lint job (shellcheck for the bash scripts, `zsh -n` syntax checks for the zsh files, since shellcheck cannot parse zsh) and fixes the existing findings so the gate starts green.

## Current state

- `.github/workflows/test.yml` — the entire CI:

```yaml
name: test

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run fast install test
        run: bash scripts/test-docker.sh
        env:
          DOTFILES_TEST_MODE: fast
```

- Bash files (shellcheck targets): `install.sh` (445+ lines, `#!/usr/bin/env bash`, `set -euo pipefail`), `lib/logging.sh` (13 lines, sourced library), `scripts/test-docker.sh`, `tests/verify.sh`, and `tests/verify-rollback.sh` (created by plan 002).
- Zsh files (`zsh -n` targets — shellcheck does NOT support zsh): `zsh/.zshenv`, `zsh/.zprofile`, `zsh/.zshrc`, `zsh/aliases.zsh`, `zsh/functions.zsh`, `zsh/completions.zsh`, `scripts/setup-colima.zsh`, `scripts/setup-services.zsh`.
- No `.shellcheckrc` exists.
- Known patterns shellcheck will likely flag (guidance, not an exhaustive list):
  - `install.sh` rollback: `latest_backup=$(ls -dt "$HOME"/.dotfiles_backup_* 2>/dev/null | head -1)` → SC2012 (parsing `ls`). This usage is intentional (mtime-ordered glob pick); suppress with an inline directive rather than rewriting.
  - `lib/logging.sh`: color variables may trigger SC2034 if any is unused (BLUE/RED/GREEN/YELLOW/NC are all used) — verify rather than assume.
  - `echo -e` in `tests/verify.sh` helpers → fine under bash; shellcheck may suggest printf (SC3037 only applies to sh — should not fire with bash shebang).
- GitHub `ubuntu-latest` runners have `shellcheck` and `zsh` available via apt; `shellcheck` is typically preinstalled. The workflow below installs both explicitly to be deterministic.
- Repo convention (AGENTS.md): all scripts use `set -euo pipefail`; aliases gate on `command -v`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Lint bash | `shellcheck install.sh lib/logging.sh scripts/test-docker.sh tests/verify.sh tests/verify-rollback.sh` | exit 0, no output |
| Syntax-check zsh | `for f in zsh/.zshenv zsh/.zprofile zsh/.zshrc zsh/aliases.zsh zsh/functions.zsh zsh/completions.zsh scripts/setup-colima.zsh scripts/setup-services.zsh; do zsh -n "$f" || echo "FAIL $f"; done` | no `FAIL` lines |
| Full test (unchanged behavior) | `DOTFILES_TEST_MODE=fast bash scripts/test-docker.sh` | exit 0 |

If `shellcheck` is missing locally, install it (`brew install shellcheck` on macOS). If `tests/verify-rollback.sh` does not exist (plan 002 not yet executed), lint the remaining four bash files and use that file list everywhere below.

## Scope

**In scope**:
- `.github/workflows/test.yml` (add `lint` job)
- `.shellcheckrc` (create)
- Minimal, behavior-preserving fixes or `# shellcheck disable=SCnnnn` directives in: `install.sh`, `lib/logging.sh`, `scripts/test-docker.sh`, `tests/verify.sh`, `tests/verify-rollback.sh`

**Out of scope** (do NOT touch):
- Zsh files (`zsh/*`, `scripts/*.zsh`) beyond confirming `zsh -n` passes — no rewrites; they are not shellcheck targets.
- Any restructuring of `install.sh` (function extraction, logic changes) — lint fixes only.
- `tests/Dockerfile`, `scripts/test-docker.sh` logic (only lint-level edits to the latter).
- Adding shfmt/formatting — deliberately excluded; formatting churn would pollute every open plan's diff.

## Git workflow

- Branch: `advisor/004-shellcheck-and-zsh-lint-ci`
- Commit style: conventional commits. Suggested: `ci: add shellcheck + zsh -n lint job` and `fix: address shellcheck findings` (two commits keeps review easy).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Create .shellcheckrc

At repo root, create `.shellcheckrc`:

```
# Resolve `source` statements relative to the script's own directory
source-path=SCRIPTDIR
external-sources=true
```

**Verify**: `cat .shellcheckrc` → matches the above.

### Step 2: Run shellcheck and fix findings

Run: `shellcheck install.sh lib/logging.sh scripts/test-docker.sh tests/verify.sh tests/verify-rollback.sh`

For each finding, apply the **least invasive** correct fix:

1. Pure quoting/robustness fixes (add quotes, `read -r`, etc.) where behavior is identical → fix in place.
2. Findings where the flagged pattern is *intentional* (e.g. SC2012 on the `ls -dt ... | head -1` backup-dir pick in `rollback()`) → add an inline directive on the line above with a one-line reason:

```bash
    # shellcheck disable=SC2012  # intentional: pick newest backup dir by mtime via glob
    latest_backup=$(ls -dt "$HOME"/.dotfiles_backup_* 2>/dev/null | head -1)
```

3. Anything that would require restructuring logic to satisfy → directive + reason, never a rewrite.

**Verify**: the shellcheck command above → exit 0, no output.

### Step 3: Confirm zsh files parse

Run the zsh `-n` loop from "Commands you will need".

**Verify**: no `FAIL` lines. (If zsh is not installed locally, `brew install zsh` is unnecessary on macOS — `/bin/zsh` exists; use it.)

### Step 4: Add the lint job to CI

In `.github/workflows/test.yml`, add a second job (keep the existing `test` job byte-identical):

```yaml
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install tools
        run: sudo apt-get update && sudo apt-get install -y shellcheck zsh
      - name: shellcheck (bash)
        run: shellcheck install.sh lib/logging.sh scripts/test-docker.sh tests/verify.sh tests/verify-rollback.sh
      - name: zsh syntax check
        run: |
          set -e
          for f in zsh/.zshenv zsh/.zprofile zsh/.zshrc zsh/aliases.zsh zsh/functions.zsh zsh/completions.zsh scripts/setup-colima.zsh scripts/setup-services.zsh; do
            zsh -n "$f"
            echo "OK $f"
          done
```

(If plan 002 was skipped and `tests/verify-rollback.sh` doesn't exist, omit it from the shellcheck line.)

**Verify**: `yq '.jobs | keys' .github/workflows/test.yml` → `["lint", "test"]` (order may vary). If `yq` is unavailable: `grep -c "runs-on: ubuntu-latest" .github/workflows/test.yml` → `2`.

### Step 5: Prove behavior is unchanged

`DOTFILES_TEST_MODE=fast bash scripts/test-docker.sh`

**Verify**: exit 0, same pass counts as before this plan's changes. Any new failure means a "fix" in Step 2 changed behavior — revert that specific fix and use a directive instead.

## Test plan

No new test files. The gates are: shellcheck exit 0, `zsh -n` exit 0 per file, and the existing Docker test proving lint fixes changed nothing. After merge, the CI `lint` job is the permanent regression net.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `shellcheck install.sh lib/logging.sh scripts/test-docker.sh tests/verify.sh tests/verify-rollback.sh` exits 0
- [ ] The zsh `-n` loop produces no `FAIL` lines
- [ ] `.github/workflows/test.yml` contains a `lint` job; the `test` job is unchanged (`git diff c38554e -- .github/workflows/test.yml` shows only additions)
- [ ] `DOTFILES_TEST_MODE=fast bash scripts/test-docker.sh` exits 0
- [ ] Every `# shellcheck disable=` directive added has a same-line or preceding-line reason comment
- [ ] `git status --porcelain` shows changes only in scoped files
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- Shellcheck reports more than ~25 findings — the codebase has drifted or something is misconfigured; report the list instead of bulk-fixing.
- A finding can only be fixed by changing what the script *does* (not how it says it) — e.g. an actually-broken quoting bug whose fix alters behavior. Report it as a bug discovery; do not silently change behavior under a lint commit.
- The Docker test fails after lint fixes and you cannot identify which fix caused it within two attempts.
- `zsh -n` fails on a file that current shells load fine — likely a zsh version difference; report rather than "fixing" working config.

## Maintenance notes

- New bash scripts must be added to **both** the shellcheck line in the workflow and the local command; new zsh files to the `-n` loop. (A follow-up could glob these lists — kept static here for explicitness.)
- Reviewer should scrutinize every `disable=` directive: each needs a credible reason, and there should be few.
- Deferred: shfmt formatting (churn), shellcheck for zsh via `--shell=bash` hacks (false positives), macOS CI matrix (backlog F11).
