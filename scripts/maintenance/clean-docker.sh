#!/usr/bin/env bash
# Prune Docker's build cache and unused images, then TRIM the Colima VM disk
# so the host reclaims the freed blocks. This is the scheduled version of the
# manual `docker-reclaim` shell function (zsh/functions.zsh).
#
# Removal scope is bounded on purpose: containers (running or stopped) and
# named volumes are NEVER removed, and no image referenced by an existing
# container is removed. What it does remove is regenerable:
#   docker builder prune -af   build cache
#   docker image prune -f      untagged/dangling images
#   docker image prune -a -f   unused *tagged* images (opt-out, see below)
#
# That last one is what actually keeps the Colima disk from filling up: tagged
# images no container references accumulate indefinitely and dangling-only
# pruning never touches them. Disable with MAINT_DOCKER_PRUNE_UNUSED_IMAGES=0.
# For anything broader (stopped containers, volumes) use `docker-cleanup` /
# `docker-cleanup-full` manually.
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

# Resolve the Colima home that actually owns the running instance. Colima
# defaults to ~/.colima and only honors $XDG_CONFIG_HOME when ~/.colima does
# not exist, so a stale ~/.colima makes `colima status` report "not running"
# and silently skip the TRIM even though the live VM lives under
# ~/.config/colima. Probe each candidate and use the one that answers.
maint_colima_home() {
    local home
    for home in "${COLIMA_HOME:-}" "${XDG_CONFIG_HOME:-$HOME/.config}/colima" "$HOME/.colima"; do
        [[ -n "$home" && -d "$home" ]] || continue
        if COLIMA_HOME="$home" colima status >/dev/null 2>&1; then
            printf '%s\n' "$home"
            return 0
        fi
    done
    return 1
}

colima_home=""
if command -v colima >/dev/null 2>&1; then
    colima_home="$(maint_colima_home)" || colima_home=""
fi

datadisk=""
if [[ -n "$colima_home" ]]; then
    datadisk="$colima_home/_lima/_disks/colima/datadisk"
fi
# Fall back to the conventional locations when the VM isn't running.
if [[ -z "$datadisk" || ! -e "$datadisk" ]]; then
    for candidate in \
        "${XDG_CONFIG_HOME:-$HOME/.config}/colima/_lima/_disks/colima/datadisk" \
        "$HOME/.colima/_lima/_disks/colima/datadisk"
    do
        [[ -e "$candidate" ]] && { datadisk="$candidate"; break; }
    done
fi

before=0
[[ -n "$datadisk" && -e "$datadisk" ]] && before="$(maint_size_bytes "$datadisk")"

prune_unused_images="${MAINT_DOCKER_PRUNE_UNUSED_IMAGES:-1}"

if maint_is_dry_run; then
    log_info "[DRY RUN] would run: docker builder prune -af"
    log_info "[DRY RUN] would run: docker image prune -f"
    [[ "$prune_unused_images" == "1" ]] && log_info "[DRY RUN] would run: docker image prune -a -f"
else
    log_info "docker builder prune -af"
    docker builder prune -af >/dev/null 2>&1 || true
    log_info "docker image prune -f"
    docker image prune -f >/dev/null 2>&1 || true
    if [[ "$prune_unused_images" == "1" ]]; then
        log_info "docker image prune -a -f (unused tagged images; containers and volumes untouched)"
        docker image prune -a -f >/dev/null 2>&1 || true
    fi
fi

if [[ -n "$colima_home" ]]; then
    if maint_is_dry_run; then
        log_info "[DRY RUN] would TRIM the Colima VM disk ($colima_home)"
    else
        log_info "TRIMming Colima VM disk ($colima_home) so the host reclaims freed blocks"
        COLIMA_HOME="$colima_home" colima ssh -- sudo fstrim -a >/dev/null 2>&1 || true
    fi
else
    log_info "Colima not running; skipped TRIM (freed blocks won't show on the host yet)"
fi

after=0
[[ -n "$datadisk" && -e "$datadisk" ]] && after="$(maint_size_bytes "$datadisk")"
freed=$((before - after))
[[ "$freed" -lt 0 ]] && freed=0

log_success "docker: freed ~$(maint_human "$freed") (build cache + unused images + VM disk trim)"
[[ "$freed" -gt 0 ]] && maint_notify "Maintenance: Docker" "Freed ~$(maint_human "$freed")"

maint_mark_ran "clean-docker"
