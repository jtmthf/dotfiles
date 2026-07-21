#!/usr/bin/env bash
# cw-hook-userprompt.sh — Claude Code `UserPromptSubmit` hook: clear waiting.
#
# Fires when the user submits a prompt (Claude is about to work again). Reads the
# hook JSON payload on stdin, pulls out session_id, and clears the per-session
# waiting marker. When running inside tmux, also unsets the window flag. A hook
# must never break Claude, so every step is guarded and the script always exits 0.
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
    cw_clear_waiting "$session_id" 2>/dev/null || true
fi

# Unset the tmux window flag for this pane (best effort).
if [[ -n "${TMUX_PANE:-}" ]] && command -v tmux >/dev/null 2>&1; then
    tmux set-option -w -u -t "$TMUX_PANE" @cw_waiting 2>/dev/null || true
fi

exit 0
