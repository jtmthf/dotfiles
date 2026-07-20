#!/usr/bin/env bash
# Shared helpers for the scheduled maintenance jobs in scripts/maintenance/.
# Sourced by each job; not meant to be executed directly.
#
# Targets bash 3.2 (macOS system /bin/bash) — no namerefs or associative arrays.

# shellcheck disable=SC2034  # config defaults are consumed by the sourcing job scripts
MAINT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAINT_DOTFILES_DIR="$(cd "$MAINT_LIB_DIR/.." && pwd)"

# shellcheck source=lib/logging.sh
source "$MAINT_LIB_DIR/logging.sh"

# launchd and cron run with a minimal PATH; make Homebrew tools (trash, git,
# node, etc.) reachable regardless of how the job was invoked.
for _maint_p in /opt/homebrew/bin /opt/homebrew/sbin /usr/local/bin /home/linuxbrew/.linuxbrew/bin; do
    if [[ -d "$_maint_p" && ":$PATH:" != *":$_maint_p:"* ]]; then
        PATH="$_maint_p:$PATH"
    fi
done
export PATH
unset _maint_p

# --- Configuration defaults (overridden by config/maintenance/config.sh) ------
MAINT_SCAN_ROOTS=("$HOME/Projects")
MAINT_NODE_MODULES_MAX_AGE_DAYS=30
MAINT_WORKTREE_MAX_AGE_DAYS=14
MAINT_TRASH_RETENTION_DAYS=30
# Minimum days between real runs of a job. The schedulers poll far more often
# than this; the gap is what enforces the weekly cadence and enables catch-up.
MAINT_MIN_INTERVAL_DAYS="${MAINT_MIN_INTERVAL_DAYS:-6}"
# Env wins over config so `--dry-run` (which exports MAINT_DRY_RUN=1) is honored.
MAINT_DRY_RUN="${MAINT_DRY_RUN:-0}"

_maint_config="$MAINT_DOTFILES_DIR/config/maintenance/config.sh"
if [[ -f "$_maint_config" ]]; then
    # shellcheck source=/dev/null
    source "$_maint_config"
fi

# --- State / logs -------------------------------------------------------------
MAINT_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-maint"
MAINT_LOG_DIR="$MAINT_STATE_DIR/logs"
MAINT_STAMP_DIR="$MAINT_STATE_DIR/last-run"
mkdir -p "$MAINT_LOG_DIR" "$MAINT_STAMP_DIR"

# True when running in preview mode (no changes made).
maint_is_dry_run() { [[ "$MAINT_DRY_RUN" == "1" || "$MAINT_DRY_RUN" == "true" ]]; }

# Returns 0 (due) when a job should run now, 1 when it ran within the last
# MAINT_MIN_INTERVAL_DAYS. Always due in dry-run so previews show work.
#
# This is the catch-up mechanism: the schedulers poll frequently (launchd every
# few hours + on the calendar slot; cron every few hours), but a job only does
# real work once its interval has elapsed. So a run missed while the Mac was
# asleep or powered off simply happens the next time the machine is awake.
maint_due() {
    local job="$1"
    maint_is_dry_run && return 0
    local stamp="$MAINT_STAMP_DIR/$job"
    [[ -f "$stamp" ]] || return 0
    local last now
    last="$(cat "$stamp" 2>/dev/null || echo 0)"
    [[ "$last" =~ ^[0-9]+$ ]] || last=0
    now="$(date +%s)"
    [[ $(( (now - last) / 86400 )) -ge "$MAINT_MIN_INTERVAL_DAYS" ]]
}

# Record a successful run so maint_due gates the next interval.
maint_mark_ran() {
    maint_is_dry_run && return 0
    date +%s > "$MAINT_STAMP_DIR/$1"
}

# Print a run header. Also stamps the (redirected) log with the current time.
maint_start() {
    MAINT_JOB="$1"
    local mode=""
    maint_is_dry_run && mode=" (dry-run)"
    log_info "=== ${MAINT_JOB} @ $(date '+%Y-%m-%d %H:%M:%S')${mode} ==="
}

# Modification time of a path as a unix epoch. Portable across BSD/GNU stat.
maint_mtime() {
    stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# Size of a path in bytes (0 if missing). Portable macOS/Linux.
maint_size_bytes() {
    local p="$1"
    [[ -e "$p" ]] || { echo 0; return; }
    if du -sk "$p" >/dev/null 2>&1; then
        echo $(( $(du -sk "$p" | awk '{print $1}') * 1024 ))
    else
        echo 0
    fi
}

# Human-readable byte count (e.g. 4.2GB). No coreutils dependency.
maint_human() {
    awk -v b="${1:-0}" 'BEGIN{
        split("B KB MB GB TB PB", u, " ");
        i = 1;
        while (b >= 1024 && i < 6) { b /= 1024; i++ }
        if (i == 1) printf "%d%s", b, u[i]; else printf "%.1f%s", b, u[i]
    }'
}

# Move a path to the Trash (recoverable). Honors dry-run. Returns non-zero if
# nothing was trashed so callers can skip counting it.
maint_trash() {
    local target="$1"
    [[ -e "$target" ]] || return 1
    if maint_is_dry_run; then
        log_info "[DRY RUN] trash: $target"
        return 0
    fi
    if command -v trash >/dev/null 2>&1; then
        trash "$target"
    elif command -v trash-put >/dev/null 2>&1; then
        trash-put "$target"
    else
        log_error "No trash CLI found (install 'trash' on macOS or 'trash-cli' on Linux); skipping: $target"
        return 1
    fi
}

# Best-effort desktop notification. Never fails the job.
maint_notify() {
    local title="$1" message="$2"
    if command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier -title "$title" -message "$message" >/dev/null 2>&1 || true
    elif [[ "$OSTYPE" == darwin* ]] && command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"${message//\"/\\\"}\" with title \"${title//\"/\\\"}\"" >/dev/null 2>&1 || true
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message" >/dev/null 2>&1 || true
    fi
}
