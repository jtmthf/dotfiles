#!/usr/bin/env bash
# Prune regenerable package-manager and build caches using each tool's native
# command. These rebuild on next use, so they are deleted outright (not trashed).
# Docker is intentionally excluded — pruning it can remove volumes (data); use
# the `docker-cleanup` shell function manually for that.
#
# Usage: clean-caches.sh [--dry-run]

set -euo pipefail

[[ "${1:-}" == "--dry-run" ]] && export MAINT_DRY_RUN=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/maintenance.sh
source "$SCRIPT_DIR/../../lib/maintenance.sh"

maint_start "clean-caches"

# Known cache locations, used to estimate reclaimed space before/after.
_maint_cache_paths() {
    command -v brew >/dev/null 2>&1 && brew --cache 2>/dev/null
    command -v npm  >/dev/null 2>&1 && npm config get cache 2>/dev/null
    command -v pnpm >/dev/null 2>&1 && pnpm store path 2>/dev/null
    command -v yarn >/dev/null 2>&1 && yarn cache dir 2>/dev/null
    command -v uv   >/dev/null 2>&1 && uv cache dir 2>/dev/null
    command -v go   >/dev/null 2>&1 && go env GOCACHE 2>/dev/null
    [[ "$OSTYPE" == darwin* ]] && echo "$HOME/Library/Developer/Xcode/DerivedData"
}

paths=()
while IFS= read -r p; do
    [[ -n "$p" && -e "$p" ]] && paths+=("$p")
done < <(_maint_cache_paths)

_maint_total_size() {
    local sum=0 pp
    if [[ ${#paths[@]} -gt 0 ]]; then
        for pp in "${paths[@]}"; do
            sum=$((sum + $(maint_size_bytes "$pp")))
        done
    fi
    echo "$sum"
}

before="$(_maint_total_size)"

# --- Prune each cache (best-effort; a failure never aborts the run) -----------
if command -v brew >/dev/null 2>&1; then
    log_info "brew cleanup -s"
    maint_is_dry_run || brew cleanup -s >/dev/null 2>&1 || true
fi
if command -v npm >/dev/null 2>&1; then
    log_info "npm cache clean --force"
    maint_is_dry_run || npm cache clean --force >/dev/null 2>&1 || true
fi
if command -v pnpm >/dev/null 2>&1; then
    log_info "pnpm store prune"
    maint_is_dry_run || pnpm store prune >/dev/null 2>&1 || true
fi
if command -v yarn >/dev/null 2>&1; then
    log_info "yarn cache clean"
    maint_is_dry_run || yarn cache clean >/dev/null 2>&1 || true
fi
if command -v uv >/dev/null 2>&1; then
    log_info "uv cache prune"
    maint_is_dry_run || uv cache prune >/dev/null 2>&1 || true
fi
if command -v go >/dev/null 2>&1; then
    log_info "go clean -cache"
    maint_is_dry_run || go clean -cache >/dev/null 2>&1 || true
fi
if [[ "$OSTYPE" == darwin* ]]; then
    derived="$HOME/Library/Developer/Xcode/DerivedData"
    if [[ -d "$derived" ]]; then
        log_info "Removing Xcode DerivedData"
        maint_is_dry_run || rm -rf "${derived:?}/"* 2>/dev/null || true
    fi
fi

after="$(_maint_total_size)"
freed=$((before - after))
[[ "$freed" -lt 0 ]] && freed=0

log_success "caches: freed ~$(maint_human "$freed") (measured across known cache dirs)"
maint_notify "Maintenance: caches" "Freed ~$(maint_human "$freed")"
