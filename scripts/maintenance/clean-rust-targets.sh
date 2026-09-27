#!/usr/bin/env bash
# Trash Cargo `target` directories in projects that have been inactive for
# longer than MAINT_RUST_TARGET_MAX_AGE_DAYS. Build output only — no source is
# touched, and everything removed is regenerable with `cargo build`. Recoverable
# via the Trash, like the other project-scoped jobs.
#
# A `target` dir is only considered when its project has a Cargo.toml, so
# unrelated directories that happen to be named `target` are ignored.
#
# Usage: clean-rust-targets.sh [--dry-run]

set -euo pipefail

[[ "${1:-}" == "--dry-run" ]] && export MAINT_DRY_RUN=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/maintenance.sh
source "$SCRIPT_DIR/../../lib/maintenance.sh"

# Skip quietly unless due (catch-up gate). Dry-run always proceeds.
maint_due "clean-rust-targets" || exit 0

maint_start "clean-rust-targets"

max_days="$MAINT_RUST_TARGET_MAX_AGE_DAYS"
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

    # -prune stops descent into a matched target, so a target nested inside
    # another project's tree isn't walked twice.
    while IFS= read -r -d '' tgt; do
        project="$(dirname "$tgt")"

        # Only Cargo build output counts.
        [[ -f "$project/Cargo.toml" ]] || continue

        # Newest activity signal: last git commit, manifest/lock mtime, project mtime.
        newest=0
        if [[ -d "$project/.git" ]]; then
            c="$(git -C "$project" log -1 --format=%ct 2>/dev/null || echo 0)"
            [[ "$c" =~ ^[0-9]+$ ]] && [[ "$c" -gt "$newest" ]] && newest="$c"
        fi
        for f in "$project/Cargo.toml" "$project/Cargo.lock"; do
            [[ -f "$f" ]] || continue
            m="$(maint_mtime "$f")"
            [[ "$m" -gt "$newest" ]] && newest="$m"
        done
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

        sz="$(maint_size_bytes "$tgt")"
        log_info "Stale ${age_days}d: $tgt ($(maint_human "$sz")) -> Trash"
        if maint_trash "$tgt"; then
            total_freed=$((total_freed + sz))
            total_count=$((total_count + 1))
        fi
    done < <(find "$root" -type d -name target -prune -print0 2>/dev/null)
done

log_success "rust targets: trashed ${total_count} dir(s), freed ~$(maint_human "$total_freed")"
if [[ "$total_count" -gt 0 ]]; then
    maint_notify "Maintenance: rust targets" "Trashed ${total_count} target(s), freed ~$(maint_human "$total_freed")"
fi

maint_mark_ran "clean-rust-targets"
