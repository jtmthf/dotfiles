#!/usr/bin/env bash
# Remove abandoned git worktrees. A linked worktree is removed only when ALL of:
#   - the working tree is clean (no uncommitted changes)
#   - it tracks an upstream and has no unpushed commits
#   - it has been untouched for MAINT_WORKTREE_MAX_AGE_DAYS
# The directory is moved to the Trash and git's metadata is pruned. Because the
# guards guarantee nothing local is lost, this is a safe, recoverable removal.
#
# Usage: clean-worktrees.sh [--dry-run]

set -euo pipefail

[[ "${1:-}" == "--dry-run" ]] && export MAINT_DRY_RUN=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/maintenance.sh
source "$SCRIPT_DIR/../../lib/maintenance.sh"

# Skip quietly unless due (catch-up gate). Dry-run always proceeds.
maint_due "clean-worktrees" || exit 0

max_days="$MAINT_WORKTREE_MAX_AGE_DAYS"
now="$(date +%s)"
removed=0
freed=0

# Evaluate a single linked worktree and, if abandoned, trash + prune it.
# Reads/updates the globals: now, max_days, removed, freed.
_maint_eval_worktree() {
    local repo="$1" main_wt="$2" wt="$3"
    [[ -n "$wt" ]] || return 0
    [[ "$wt" == "$main_wt" ]] && return 0
    [[ -d "$wt" ]] || return 0

    if [[ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]]; then
        log_info "Keep (uncommitted changes): $wt"
        return 0
    fi

    local upstream ahead
    upstream="$(git -C "$wt" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo "")"
    if [[ -z "$upstream" ]]; then
        log_info "Keep (no upstream / detached): $wt"
        return 0
    fi
    ahead="$(git -C "$wt" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 1)"
    if [[ "$ahead" != "0" ]]; then
        log_info "Keep (${ahead} unpushed commit(s)): $wt"
        return 0
    fi

    local newest=0 c m age_days
    c="$(git -C "$wt" log -1 --format=%ct 2>/dev/null || echo 0)"
    [[ "$c" =~ ^[0-9]+$ ]] && [[ "$c" -gt "$newest" ]] && newest="$c"
    m="$(maint_mtime "$wt")"
    [[ "$m" -gt "$newest" ]] && newest="$m"
    if [[ "$newest" -eq 0 ]]; then
        log_info "Keep (no activity signal): $wt"
        return 0
    fi
    age_days=$(( (now - newest) / 86400 ))
    if [[ "$age_days" -lt "$max_days" ]]; then
        log_info "Keep (active ${age_days}d): $wt"
        return 0
    fi

    local sz
    sz="$(maint_size_bytes "$wt")"
    log_info "Abandoned ${age_days}d, clean + pushed: $wt ($(maint_human "$sz")) -> Trash"
    if maint_trash "$wt"; then
        maint_is_dry_run || git -C "$repo" worktree prune 2>/dev/null || true
        removed=$((removed + 1))
        freed=$((freed + sz))
    fi
}

if [[ ${#MAINT_SCAN_ROOTS[@]} -eq 0 ]]; then
    log_warning "No scan roots configured (MAINT_SCAN_ROOTS is empty)"
    exit 0
fi

maint_start "clean-worktrees"

for root in "${MAINT_SCAN_ROOTS[@]}"; do
    [[ -d "$root" ]] || { log_info "Skip (missing root): $root"; continue; }
    log_info "Scanning $root for git repos"

    # A main repo has a .git directory; linked worktrees have a .git *file*, so
    # -type d matches only the primary repos. `git worktree list` then reports
    # every linked worktree by absolute path, wherever it lives.
    while IFS= read -r -d '' gitdir; do
        repo="$(dirname "$gitdir")"
        main_wt="$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null || echo "")"
        [[ -n "$main_wt" ]] || continue

        wt=""
        # Trailing newline guarantees the final porcelain record is flushed.
        while IFS= read -r line; do
            case "$line" in
                "worktree "*) wt="${line#worktree }" ;;
                "") _maint_eval_worktree "$repo" "$main_wt" "$wt"; wt="" ;;
            esac
        done < <(git -C "$repo" worktree list --porcelain 2>/dev/null; printf '\n')
    done < <(find "$root" -maxdepth 4 -type d -name .git -print0 2>/dev/null)
done

log_success "worktrees: removed ${removed}, freed ~$(maint_human "$freed")"
if [[ "$removed" -gt 0 ]]; then
    maint_notify "Maintenance: worktrees" "Removed ${removed} abandoned worktree(s), freed ~$(maint_human "$freed")"
fi

maint_mark_ran "clean-worktrees"
