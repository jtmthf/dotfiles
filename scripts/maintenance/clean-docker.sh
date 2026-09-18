#!/usr/bin/env bash
# Prune Docker's build cache and dangling images, then TRIM the Colima VM disk
# so the host reclaims the freed blocks. This is the scheduled version of the
# manual `docker-reclaim` shell function (zsh/functions.zsh) — same commands.
#
# Deliberately conservative, unlike the other jobs in this directory: it never
# touches containers (running or stopped) or named volumes, and never removes a
# tagged image still referenced by a container. `docker builder prune -af`
# (cache) and `docker image prune -f` (untagged/dangling only) can only remove
# things nothing depends on, so nothing you'd come back looking for disappears.
# For anything more aggressive, use `docker-cleanup` / `docker-cleanup-full`
# manually.
#
# Usage: clean-docker.sh [--dry-run]

set -euo pipefail

[[ "${1:-}" == "--dry-run" ]] && export MAINT_DRY_RUN=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/maintenance.sh
source "$SCRIPT_DIR/../../lib/maintenance.sh"

# Nothing to do if Docker isn't installed at all.
command -v docker >/dev/null 2>&1 || exit 0

# Skip quietly unless due (catch-up gate). Dry-run always proceeds.
maint_due "clean-docker" || exit 0

maint_start "clean-docker"

datadisk="${XDG_CONFIG_HOME:-$HOME/.config}/colima/_lima/_disks/colima/datadisk"
[[ -e "$datadisk" ]] || datadisk="$HOME/.colima/_lima/_disks/colima/datadisk"

before=0
[[ -e "$datadisk" ]] && before="$(maint_size_bytes "$datadisk")"

if maint_is_dry_run; then
    log_info "[DRY RUN] would run: docker builder prune -af"
    log_info "[DRY RUN] would run: docker image prune -f"
else
    log_info "docker builder prune -af"
    docker builder prune -af >/dev/null 2>&1 || true
    log_info "docker image prune -f"
    docker image prune -f >/dev/null 2>&1 || true
fi

if command -v colima >/dev/null 2>&1 && colima status >/dev/null 2>&1; then
    if maint_is_dry_run; then
        log_info "[DRY RUN] would TRIM the Colima VM disk"
    else
        log_info "TRIMming Colima VM disk so the host reclaims freed blocks"
        colima ssh -- sudo fstrim -a >/dev/null 2>&1 || true
    fi
else
    log_info "Colima not running; skipped TRIM (freed blocks won't show on the host yet)"
fi

after=0
[[ -e "$datadisk" ]] && after="$(maint_size_bytes "$datadisk")"
freed=$((before - after))
[[ "$freed" -lt 0 ]] && freed=0

log_success "docker: freed ~$(maint_human "$freed") (build cache + dangling images + VM disk trim)"
[[ "$freed" -gt 0 ]] && maint_notify "Maintenance: Docker" "Freed ~$(maint_human "$freed")"

maint_mark_ran "clean-docker"
