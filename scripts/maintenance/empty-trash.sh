#!/usr/bin/env bash
# Permanently delete trashed items older than MAINT_TRASH_RETENTION_DAYS, so the
# recovery window from the other jobs doesn't itself fill the disk.
#
# Linux (trash-cli): uses the recorded deletion date (accurate).
# macOS: purges ~/.Trash entries by ctime, which is updated when an item is moved
#   into the Trash on the same volume — a good proxy for time-in-trash.
#
# Usage: empty-trash.sh [--dry-run]

set -euo pipefail

[[ "${1:-}" == "--dry-run" ]] && export MAINT_DRY_RUN=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/maintenance.sh
source "$SCRIPT_DIR/../../lib/maintenance.sh"

maint_start "empty-trash"

days="$MAINT_TRASH_RETENTION_DAYS"

# Linux trash-cli tracks deletion dates, so let it do the age filtering.
if [[ "$OSTYPE" == linux* ]] && command -v trash-empty >/dev/null 2>&1; then
    log_info "Emptying trashed items older than ${days} days (trash-cli)"
    if maint_is_dry_run; then
        log_info "[DRY RUN] would run: trash-empty $days"
    else
        trash-empty -f "$days" 2>/dev/null || trash-empty "$days" || true
    fi
    log_success "empty-trash complete"
    maint_notify "Maintenance: Trash" "Emptied items older than ${days}d"
    exit 0
fi

trash_dir="$HOME/.Trash"
if [[ ! -d "$trash_dir" ]]; then
    log_info "No Trash directory at $trash_dir"
    exit 0
fi

freed=0
count=0
while IFS= read -r -d '' item; do
    sz="$(maint_size_bytes "$item")"
    log_info "Purge (in trash >${days}d): $item ($(maint_human "$sz"))"
    if ! maint_is_dry_run; then
        rm -rf "$item" 2>/dev/null || true
    fi
    freed=$((freed + sz))
    count=$((count + 1))
done < <(find "$trash_dir" -mindepth 1 -maxdepth 1 -ctime +"$days" -print0 2>/dev/null)

log_success "empty-trash: purged ${count} item(s), freed ~$(maint_human "$freed")"
if [[ "$count" -gt 0 ]]; then
    maint_notify "Maintenance: Trash" "Purged ${count} item(s), freed ~$(maint_human "$freed")"
fi
