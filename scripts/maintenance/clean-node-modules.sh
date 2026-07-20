#!/usr/bin/env bash
# Trash node_modules directories in projects that have been inactive for longer
# than MAINT_NODE_MODULES_MAX_AGE_DAYS. Recoverable via the Trash.
#
# Usage: clean-node-modules.sh [--dry-run]

set -euo pipefail

[[ "${1:-}" == "--dry-run" ]] && export MAINT_DRY_RUN=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/maintenance.sh
source "$SCRIPT_DIR/../../lib/maintenance.sh"

maint_start "clean-node-modules"

max_days="$MAINT_NODE_MODULES_MAX_AGE_DAYS"
now="$(date +%s)"
total_freed=0
total_count=0

if [[ ${#MAINT_SCAN_ROOTS[@]} -eq 0 ]]; then
    log_warning "No scan roots configured (MAINT_SCAN_ROOTS is empty)"
    exit 0
fi

for root in "${MAINT_SCAN_ROOTS[@]}"; do
    [[ -d "$root" ]] || { log_info "Skip (missing root): $root"; continue; }
    log_info "Scanning $root"

    # -prune stops descent into a matched node_modules, so nested copies inside
    # a hit aren't listed; package-level node_modules in monorepos still are.
    while IFS= read -r -d '' nm; do
        project="$(dirname "$nm")"

        # Newest activity signal: last git commit, package.json mtime, dir mtime.
        newest=0
        if [[ -d "$project/.git" ]]; then
            c="$(git -C "$project" log -1 --format=%ct 2>/dev/null || echo 0)"
            [[ "$c" =~ ^[0-9]+$ ]] && [[ "$c" -gt "$newest" ]] && newest="$c"
        fi
        if [[ -f "$project/package.json" ]]; then
            m="$(maint_mtime "$project/package.json")"
            [[ "$m" -gt "$newest" ]] && newest="$m"
        fi
        m="$(maint_mtime "$project")"
        [[ "$m" -gt "$newest" ]] && newest="$m"

        if [[ "$newest" -eq 0 ]]; then
            log_info "Keep (no activity signal): $project"
            continue
        fi

        age_days=$(( (now - newest) / 86400 ))
        if [[ "$age_days" -lt "$max_days" ]]; then
            continue
        fi

        sz="$(maint_size_bytes "$nm")"
        log_info "Stale ${age_days}d: $nm ($(maint_human "$sz")) -> Trash"
        if maint_trash "$nm"; then
            total_freed=$((total_freed + sz))
            total_count=$((total_count + 1))
        fi
    done < <(find "$root" -type d -name node_modules -prune -print0 2>/dev/null)
done

log_success "node_modules: trashed ${total_count} dir(s), freed ~$(maint_human "$total_freed")"
if [[ "$total_count" -gt 0 ]]; then
    maint_notify "Maintenance: node_modules" "Trashed ${total_count} project(s), freed ~$(maint_human "$total_freed")"
fi
