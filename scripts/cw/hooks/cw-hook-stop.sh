#!/usr/bin/env bash
# cw-hook-stop.sh — Claude Code `Stop` hook: mark this session as waiting.
#
# Fires when Claude finishes responding and is waiting for user input. Reads the
# hook JSON payload on stdin, pulls out session_id, and sets the per-session
# waiting marker. When running inside tmux, also flags the window so the status
# line / dashboard can render it. A hook must never break Claude, so every step
# is guarded and the script always exits 0.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the shared lib (two dirs up: scripts/cw/cw-lib.sh). Bail out cleanly if
# it (or its lone hard dep, jq) is missing — we still must not fail the hook.
lib="$SCRIPT_DIR/../cw-lib.sh"
[[ -f "$lib" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
# shellcheck source=../cw-lib.sh
source "$lib" || exit 0

payload="$(cat 2>/dev/null || true)"
session_id="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null || true)"

if [[ -n "$session_id" ]]; then
    cw_set_waiting "$session_id" 2>/dev/null || true
fi

# Flag the tmux window this pane lives in (best effort).
if [[ -n "${TMUX_PANE:-}" ]] && command -v tmux >/dev/null 2>&1; then
    tmux set-option -w -t "$TMUX_PANE" @cw_waiting 1 2>/dev/null || true
fi

exit 0
