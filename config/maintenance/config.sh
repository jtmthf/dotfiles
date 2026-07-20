# shellcheck shell=bash
# shellcheck disable=SC2034  # consumed by lib/maintenance.sh and the job scripts
# Tunables for the scheduled maintenance jobs (scripts/maintenance/).
# Sourced by lib/maintenance.sh. Edit here — no need to touch the job scripts.

# Directories to scan for stale node_modules and abandoned git worktrees.
# One entry per line; ~ / $HOME are expanded.
MAINT_SCAN_ROOTS=(
    "$HOME/Projects"
)

# Trash a project's node_modules once the project has had no git commit or file
# activity for at least this many days.
MAINT_NODE_MODULES_MAX_AGE_DAYS=30

# Remove a git worktree only when it is clean (no uncommitted changes) AND fully
# pushed (upstream exists, no unpushed commits) AND untouched for this many days.
MAINT_WORKTREE_MAX_AGE_DAYS=14

# empty-trash permanently deletes trashed items older than this many days.
MAINT_TRASH_RETENTION_DAYS=30

# Minimum days between real runs of any job. The schedulers poll more often than
# this (launchd every ~6h + the Sunday slot; cron every ~6h); a job only does
# work once this many days have passed, which is what lets a run missed while the
# Mac was asleep/off happen the next time it is awake. Lower it to run more often.
MAINT_MIN_INTERVAL_DAYS="${MAINT_MIN_INTERVAL_DAYS:-6}"

# Set to 1 to preview every job without making changes. Overridden per-run by
# passing --dry-run to a job script.
MAINT_DRY_RUN="${MAINT_DRY_RUN:-0}"
