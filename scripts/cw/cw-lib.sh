#!/usr/bin/env bash
# cw-lib.sh — shared primitives for the cw worktree/session workflow.
#
# Sourced by `cw`, the dashboard popup, and the Claude hooks. This is the single
# source of truth for paths, the manifest schema, zoxide registration, and the
# "agent is waiting" markers. Keep it POSIX-bash and dependency-light: jq is the
# only hard requirement (git/zoxide/tmux are probed, never assumed).
#
# ── Manifest schema (${XDG_STATE_HOME:-~/.local/state}/cw/manifest.json) ──────
# {
#   "worktrees": {
#     "<abs-worktree-path>": {
#       "repo":        "dotfiles",
#       "branch":      "feature/x",
#       "session":     "dotfiles-feature-x",   # tmux session name
#       "note":        "…",                    # free text ("" if unset)
#       "note_source": "manual" | "haiku" | "",
#       "created":     "2026-07-21T12:00:00Z",
#       "sessions": {                          # Claude Code sessions cw launched
#         "<uuid>": { "name": "feature-x", "pane": "sess:win.pane", "created": "…" }
#       }
#     }
#   }
# }
#
# Waiting markers live at $(cw_waiting_dir)/<session-uuid> — presence == waiting.

# Guard against double-sourcing.
[[ -n "${_CW_LIB_LOADED:-}" ]] && return 0
_CW_LIB_LOADED=1

# ── Paths ────────────────────────────────────────────────────────────────────

cw_state_dir()   { printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}/cw"; }
cw_manifest()    { printf '%s\n' "$(cw_state_dir)/manifest.json"; }
cw_waiting_dir() { printf '%s\n' "$(cw_state_dir)/waiting"; }
cw_pr_cache()    { printf '%s\n' "$(cw_state_dir)/pr-cache.json"; }

# Slugify a branch name for use in paths/session names: '/' and whitespace → '-'.
# Note: no trailing newline into tr, or it would become a stray '-'.
cw_slug() {
    printf '%s' "$1" | tr '/[:space:]' '-'
}

# Absolute path of the *main* worktree for the repo containing $PWD (or $1).
cw_repo_root() {
    local dir="${1:-$PWD}"
    git -C "$dir" worktree list --porcelain 2>/dev/null \
        | awk '/^worktree /{print $2; exit}'
}

cw_repo_name() { basename "$(cw_repo_root "${1:-$PWD}")"; }

# Worktree path for a branch:  <main-root>/.claude/worktrees/<slug>
cw_wt_path() {
    local main_root="$1" branch="$2"
    printf '%s\n' "$main_root/.claude/worktrees/$(cw_slug "$branch")"
}

# tmux session name for a repo+branch:  <repo>-<slug>
cw_session_name() {
    local repo="$1" branch="$2"
    printf '%s\n' "${repo}-$(cw_slug "$branch")"
}

# UTC timestamp, ISO-8601.
cw_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# ── State bootstrap ──────────────────────────────────────────────────────────

cw_ensure_state() {
    local sdir; sdir="$(cw_state_dir)"
    mkdir -p "$sdir" "$(cw_waiting_dir)"
    local m; m="$(cw_manifest)"
    [[ -f "$m" ]] || printf '{"worktrees":{}}\n' > "$m"
}

# ── Manifest access (atomic writes, coarse lock) ─────────────────────────────
# All mutations funnel through cw_manifest_edit, which runs a jq program against
# the current manifest and swaps the result in atomically. A mkdir-based lock
# serializes concurrent cw/hook/dashboard writers.

_cw_lock() {
    local lock; lock="$(cw_state_dir)/.lock"
    local tries=0
    until mkdir "$lock" 2>/dev/null; do
        (( tries++ >= 100 )) && { rm -rf "$lock"; mkdir "$lock" 2>/dev/null || return 1; }
        sleep 0.05
    done
}
_cw_unlock() { rmdir "$(cw_state_dir)/.lock" 2>/dev/null || true; }

# cw_manifest_edit '<jq program>' [jq-args...]
# The jq program receives the manifest as input; its stdout becomes the new
# manifest. Pass values in with --arg/--argjson via extra args.
cw_manifest_edit() {
    cw_ensure_state
    local prog="$1"; shift
    local m tmp; m="$(cw_manifest)"; tmp="${m}.tmp.$$"
    _cw_lock || { echo "cw: could not acquire manifest lock" >&2; return 1; }
    if jq "$@" "$prog" "$m" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$m"
        _cw_unlock
    else
        rm -f "$tmp"; _cw_unlock
        echo "cw: manifest update failed" >&2; return 1
    fi
}

# cw_manifest_query '<jq program>' [jq-args...] — read-only, no lock.
cw_manifest_query() {
    cw_ensure_state
    local prog="$1"; shift
    jq "$@" "$prog" "$(cw_manifest)" 2>/dev/null
}

# ── Worktree records ─────────────────────────────────────────────────────────

# cw_wt_upsert <wt_path> <repo> <branch> <session>
cw_wt_upsert() {
    local p="$1" repo="$2" branch="$3" session="$4"
    cw_manifest_edit '
        .worktrees[$p] //= {sessions:{}}
        | .worktrees[$p].repo    = $repo
        | .worktrees[$p].branch  = $branch
        | .worktrees[$p].session = $session
        | .worktrees[$p].created //= $now
        | .worktrees[$p].note        //= ""
        | .worktrees[$p].note_source //= ""
        | .worktrees[$p].sessions    //= {}
    ' --arg p "$p" --arg repo "$repo" --arg branch "$branch" \
      --arg session "$session" --arg now "$(cw_now)"
}

# cw_wt_set_note <wt_path> <note> <source>
cw_wt_set_note() {
    cw_manifest_edit '
        .worktrees[$p].note = $note | .worktrees[$p].note_source = $src
    ' --arg p "$1" --arg note "$2" --arg src "$3"
}

# cw_wt_add_session <wt_path> <uuid> <name> <pane>
cw_wt_add_session() {
    cw_manifest_edit '
        .worktrees[$p].sessions[$id] = {name:$name, pane:$pane, created:$now}
    ' --arg p "$1" --arg id "$2" --arg name "$3" --arg pane "$4" --arg now "$(cw_now)"
}

# cw_wt_set_pane <wt_path> <uuid> <pane> — update a session's live pane id.
cw_wt_set_pane() {
    cw_manifest_edit '
        if .worktrees[$p].sessions[$id] then
            .worktrees[$p].sessions[$id].pane = $pane
        else . end
    ' --arg p "$1" --arg id "$2" --arg pane "$3"
}

# cw_wt_remove <wt_path>
cw_wt_remove() {
    cw_manifest_edit 'del(.worktrees[$p])' --arg p "$1"
}

# cw_wt_json <wt_path> — echo the worktree record (or empty).
cw_wt_json() {
    cw_manifest_query '.worktrees[$p] // empty' --arg p "$1"
}

# cw_list_wt_paths — one absolute worktree path per line.
cw_list_wt_paths() {
    cw_manifest_query -r '.worktrees | keys[]'
}

# cw_wt_next_session_name <wt_path> <base> — base, then base-2, base-3, …
cw_wt_next_session_name() {
    local p="$1" base="$2" existing n=1 candidate="$2"
    existing="$(cw_manifest_query -r '.worktrees[$p].sessions | to_entries[].value.name' --arg p "$p")"
    while printf '%s\n' "$existing" | grep -qx "$candidate"; do
        n=$((n+1)); candidate="${base}-${n}"
    done
    printf '%s\n' "$candidate"
}

# ── zoxide ───────────────────────────────────────────────────────────────────

cw_zoxide_add() {
    command -v zoxide >/dev/null 2>&1 && [[ -d "$1" ]] && zoxide add "$1" 2>/dev/null || true
}
cw_zoxide_remove() {
    command -v zoxide >/dev/null 2>&1 && zoxide remove "$1" 2>/dev/null || true
}

# ── Waiting markers (driven by Claude Stop / UserPromptSubmit hooks) ──────────

cw_waiting_marker() { printf '%s\n' "$(cw_waiting_dir)/$1"; }
cw_set_waiting()    { cw_ensure_state; : > "$(cw_waiting_marker "$1")"; }
cw_clear_waiting()  { rm -f "$(cw_waiting_marker "$1")" 2>/dev/null || true; }
cw_is_waiting()     { [[ -f "$(cw_waiting_marker "$1")" ]]; }

# Count sessions of a worktree that are currently waiting.
cw_wt_waiting_count() {
    local p="$1" ids id c=0
    ids="$(cw_manifest_query -r '.worktrees[$p].sessions | keys[]' --arg p "$p")"
    for id in $ids; do cw_is_waiting "$id" && c=$((c+1)); done
    printf '%s\n' "$c"
}

# Given a Claude session uuid, echo the worktree path that owns it (or empty).
cw_session_worktree() {
    cw_manifest_query -r --arg id "$1" '
        .worktrees | to_entries[] | select(.value.sessions[$id]) | .key
    ' | head -n1
}
