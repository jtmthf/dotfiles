#!/usr/bin/env bash
# cw-dashboard.sh — Conductor/cmux-style board for cw worktrees + Claude sessions.
#
# Runs inside a tmux `display-popup -E` (its own TTY). It reads the cw manifest
# via cw-lib.sh and drives the *outer* tmux client with `tmux` commands. Two
# levels, both fzf-driven:
#   L1  worktree board across ALL repos
#   L2  Claude sessions of one worktree
#
# It also serves its own fzf preview panes and PR-cache refresh via hidden
# subcommands (--preview / --preview-session / --refresh-pr). Everything degrades
# gracefully when tmux / gh / claude / git are missing or a worktree dir is gone.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./cw-lib.sh
source "$SCRIPT_DIR/cw-lib.sh"

SELF="$SCRIPT_DIR/cw-dashboard.sh"
TAB=$'\t'
PR_TTL=600   # seconds before a cached PR entry is considered stale

# BSD (macOS) vs GNU stat detection, done once.
if stat -f '%m' . >/dev/null 2>&1; then _STAT_BSD=1; else _STAT_BSD=0; fi

# ── small utilities ──────────────────────────────────────────────────────────

_have() { command -v "$1" >/dev/null 2>&1; }

_stat_mtime() {  # epoch mtime of a path (int)
    if (( _STAT_BSD )); then stat -f '%m' "$1" 2>/dev/null; else stat -c '%Y' "$1" 2>/dev/null; fi
}

# Newest file mtime under a directory (epoch int), empty if none/absent.
_newest_mtime() {
    local dir="$1" m
    [[ -d "$dir" ]] || return 0
    if (( _STAT_BSD )); then
        m="$(find "$dir" -type f -not -path '*/.git/*' -exec stat -f '%m' {} + 2>/dev/null | sort -rn | head -n1)"
    else
        m="$(find "$dir" -type f -not -path '*/.git/*' -printf '%T@\n' 2>/dev/null | sort -rn | head -n1)"
    fi
    printf '%s' "${m%.*}"
}

# Claude project dir for a worktree cwd: ~/.claude/projects/<path with / and . → ->
_claude_project_dir() {
    local m="$1"
    m="${m//\//-}"; m="${m//./-}"
    printf '%s/.claude/projects/%s' "$HOME" "$m"
}

# Last activity epoch for a worktree: newest file in its Claude project dir,
# else the worktree dir's own mtime.
_wt_last_activity() {
    local path="$1" proj m
    proj="$(_claude_project_dir "$path")"
    m="$(_newest_mtime "$proj")"
    [[ -n "$m" ]] && { printf '%s' "$m"; return 0; }
    [[ -d "$path" ]] && _stat_mtime "$path"
    return 0
}

_human_age() {
    local mt="$1" now diff
    [[ -n "$mt" ]] || { printf '-'; return; }
    now="$(date +%s)"; diff=$(( now - mt ))
    (( diff < 0 )) && diff=0
    if   (( diff < 60 ));    then printf '%ds' "$diff"
    elif (( diff < 3600 ));  then printf '%dm' $(( diff / 60 ))
    elif (( diff < 86400 )); then printf '%dh' $(( diff / 3600 ))
    else                          printf '%dd' $(( diff / 86400 )); fi
}

# Default diff base for a worktree (origin/HEAD → main → master → HEAD).
_base_ref() {
    local dir="$1" ref b
    ref="$(git -C "$dir" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)"
    if [[ -n "$ref" ]]; then printf '%s' "${ref#refs/remotes/}"; return; fi
    for b in main master; do
        git -C "$dir" show-ref --verify --quiet "refs/heads/$b" && { printf '%s' "$b"; return; }
    done
    printf 'HEAD'
}

_pane_alive() {  # is a tmux pane id ($1) currently live?
    local pane="$1"
    [[ -n "$pane" ]] || return 1
    _have tmux || return 1
    tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -qxF "$pane"
}

_prompt() {  # read a line from the real tty; echo it
    local q="$1" ans=""
    read -r -p "$q" ans </dev/tty 2>/dev/null || true
    printf '%s' "$ans"
}

_q() { cw_manifest_query -r "$@"; }   # short read-only query helper

# ── PR cache ─────────────────────────────────────────────────────────────────

# refresh_pr_cache [force] — refresh gh PR data for every branch with a worktree.
# Slow; meant to run in the background. Refreshes an entry only if forced,
# missing, or older than $PR_TTL. Never blocks: writes the cache atomically.
refresh_pr_cache() {
    _have gh || return 0
    _have jq || return 0
    local force="${1:-}" cache tmp path branch fetched now age json
    cache="$(cw_pr_cache)"; tmp="${cache}.tmp.$$"
    now="$(date +%s)"
    [[ -f "$cache" ]] || printf '{}\n' > "$cache"

    while IFS= read -r path; do
        [[ -n "$path" ]] || continue
        [[ -d "$path" ]] || continue
        branch="$(_q '.worktrees[$p].branch // empty' --arg p "$path")"
        [[ -n "$branch" ]] || continue
        if [[ "$force" != "force" ]]; then
            fetched="$(jq -r --arg p "$path" '.[$p].fetched // 0' "$cache" 2>/dev/null || echo 0)"
            age=$(( now - fetched ))
            (( age < PR_TTL )) && continue
        fi
        # gh needs a repo context; run from the worktree so it resolves the remote.
        json="$( ( cd "$path" 2>/dev/null && gh pr view "$branch" --json state,isDraft,statusCheckRollup,title,url 2>/dev/null ) || true )"
        if [[ -n "$json" ]]; then
            jq --arg p "$path" --argjson now "$now" --argjson d "$json" \
               '.[$p] = {fetched:$now, data:$d}' "$cache" > "$tmp" 2>/dev/null \
               && mv "$tmp" "$cache"
        else
            jq --arg p "$path" --argjson now "$now" \
               '.[$p] = {fetched:$now, data:null}' "$cache" > "$tmp" 2>/dev/null \
               && mv "$tmp" "$cache"
        fi
    done < <(cw_list_wt_paths)
    rm -f "$tmp" 2>/dev/null || true
}

# _pr_frag <path> — compact PR cell: "OPEN ✓" / "DRAFT •" / "—".
_pr_frag() {
    local p="$1" cache; cache="$(cw_pr_cache)"
    [[ -f "$cache" ]] || { printf '—'; return; }
    _have jq || { printf '—'; return; }
    jq -r --arg p "$p" '
        (.[$p].data) as $d
        | if $d == null then "—"
          else
            (if $d.isDraft then "DRAFT" else ($d.state // "—") end) as $st
            | (($d.statusCheckRollup // [])) as $r
            | ($r | map(.conclusion // .state // .status // "")) as $c
            | (($c | map(select(. == "FAILURE" or . == "ERROR" or . == "TIMED_OUT" or . == "CANCELLED")) | length)) as $fail
            | (($c | map(select(. == "PENDING" or . == "IN_PROGRESS" or . == "QUEUED")) | length)) as $pend
            | (if ($r|length) == 0 then "" elif $fail > 0 then " ✗" elif $pend > 0 then " •" else " ✓" end) as $g
            | $st + $g
          end
    ' "$cache" 2>/dev/null || printf '—'
}

# ── LEVEL 1: row building (pure — no fzf/tmux dependency for the row text) ────

# build_level1_rows — one "path<TAB>display" line per manifest worktree.
build_level1_rows() {
    local path repo branch session note live dirty base lr behind ahead gitcol
    local nsess waiting sess mt age pr disp label
    while IFS= read -r path; do
        [[ -n "$path" ]] || continue
        IFS="$TAB" read -r repo branch session note < <(
            cw_manifest_query -r --arg p "$path" \
                '.worktrees[$p] | [(.repo // "?"), (.branch // "?"), (.session // ""), (.note // "")] | @tsv'
        )

        live="○"
        if _have tmux && [[ -n "$session" ]] && tmux has-session -t "$session" 2>/dev/null; then
            live="●"
        fi

        if [[ -d "$path" ]] && _have git; then
            dirty="$( { git -C "$path" status --porcelain 2>/dev/null || true; } | wc -l | tr -d ' ')"
            base="$(_base_ref "$path")"
            lr="$(git -C "$path" rev-list --left-right --count "${base}...HEAD" 2>/dev/null || printf '0\t0')"
            behind="$(printf '%s' "$lr" | awk '{print $1+0}')"
            ahead="$(printf '%s' "$lr" | awk '{print $2+0}')"
            gitcol="$(printf '±%s ↑%s↓%s' "$dirty" "$ahead" "$behind")"
        else
            gitcol="(missing)"
        fi

        nsess="$(_q '.worktrees[$p].sessions | length' --arg p "$path")"
        [[ -n "$nsess" ]] || nsess=0
        waiting="$(cw_wt_waiting_count "$path")"
        sess="${nsess} sess"
        (( waiting > 0 )) && sess="${sess} ${waiting}⚠"

        mt="$(_wt_last_activity "$path")"
        age="$(_human_age "$mt")"

        pr="$(_pr_frag "$path")"

        label="${repo}/${branch}"
        label="${label:0:26}"
        note="${note:0:40}"

        disp="$(printf '%s %-26s %-15s %-9s %-11s %-4s %s' \
            "$live" "$label" "$gitcol" "$pr" "$sess" "$age" "$note")"
        printf '%s\t%s\n' "$path" "$disp"
    done < <(cw_list_wt_paths)
}

# ── LEVEL 1: preview ─────────────────────────────────────────────────────────

preview_level1() {
    local path="$1" branch session base cache
    branch="$(_q '.worktrees[$p].branch // "?"' --arg p "$path")"
    session="$(_q '.worktrees[$p].session // ""' --arg p "$path")"

    printf '\033[1m%s\033[0m\n%s\n\n' "$branch" "$path"

    if [[ ! -d "$path" ]]; then
        printf '(worktree directory is missing)\n\n'
    elif _have git; then
        base="$(_base_ref "$path")"
        git -C "$path" -c color.status=always status -sb 2>/dev/null | head -n 20 || true
        printf '\n'
        printf '\033[1mdiff vs %s\033[0m\n' "$base"
        git -C "$path" diff --stat "${base}...HEAD" 2>/dev/null | head -n 25 || true
        printf '\n'
    fi

    cache="$(cw_pr_cache)"
    if [[ -f "$cache" ]] && _have jq; then
        local title url
        title="$(jq -r --arg p "$path" '.[$p].data.title // empty' "$cache" 2>/dev/null || true)"
        url="$(jq -r --arg p "$path" '.[$p].data.url // empty' "$cache" 2>/dev/null || true)"
        if [[ -n "$title" || -n "$url" ]]; then
            printf '\033[1mPR\033[0m %s\n%s\n\n' "$(_pr_frag "$path")" "$title"
            [[ -n "$url" ]] && printf '%s\n\n' "$url"
        fi
    fi

    printf '\033[1msessions\033[0m\n'
    local ids id name pane state act mt proj f
    ids="$(_q '.worktrees[$p].sessions | keys[]' --arg p "$path" 2>/dev/null || true)"
    if [[ -z "$ids" ]]; then
        printf '  (none)\n'
        return 0
    fi
    proj="$(_claude_project_dir "$path")"
    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        name="$(_q '.worktrees[$p].sessions[$id].name // "?"' --arg p "$path" --arg id "$id")"
        pane="$(_q '.worktrees[$p].sessions[$id].pane // ""' --arg p "$path" --arg id "$id")"
        if _pane_alive "$pane"; then state="live"; else state="resumable"; fi
        cw_is_waiting "$id" && state="$state ⚠"
        f="$proj/$id.jsonl"; act="-"
        [[ -f "$f" ]] && act="$(_human_age "$(_stat_mtime "$f")")"
        printf '  %-16s %-14s %s\n' "$name" "$state" "$act"
    done <<< "$ids"
}

# ── LEVEL 2: rows + preview ──────────────────────────────────────────────────

# build_level2_rows <path> — one "uuid<TAB>display" per Claude session.
build_level2_rows() {
    local path="$1" ids id name pane state act proj f
    ids="$(_q '.worktrees[$p].sessions | keys[]' --arg p "$path" 2>/dev/null || true)"
    [[ -n "$ids" ]] || return 0
    proj="$(_claude_project_dir "$path")"
    while IFS= read -r id; do
        [[ -n "$id" ]] || continue
        name="$(_q '.worktrees[$p].sessions[$id].name // "?"' --arg p "$path" --arg id "$id")"
        pane="$(_q '.worktrees[$p].sessions[$id].pane // ""' --arg p "$path" --arg id "$id")"
        if _pane_alive "$pane"; then state="live"; else state="resumable"; fi
        local warn=" "; cw_is_waiting "$id" && warn="⚠"
        f="$proj/$id.jsonl"; act="-"
        [[ -f "$f" ]] && act="$(_human_age "$(_stat_mtime "$f")")"
        printf '%s\t%s %-16s %-11s %s\n' "$id" "$warn" "$name" "$state" "$act"
    done <<< "$ids"
}

preview_level2() {
    local path="$1" uuid="$2" name pane created state proj f
    name="$(_q '.worktrees[$p].sessions[$id].name // "?"' --arg p "$path" --arg id "$uuid")"
    pane="$(_q '.worktrees[$p].sessions[$id].pane // ""' --arg p "$path" --arg id "$uuid")"
    created="$(_q '.worktrees[$p].sessions[$id].created // "?"' --arg p "$path" --arg id "$uuid")"
    if _pane_alive "$pane"; then state="live ($pane)"; else state="resumable"; fi
    cw_is_waiting "$uuid" && state="$state · waiting on you ⚠"

    printf '\033[1m%s\033[0m\n' "$name"
    printf 'uuid    %s\n' "$uuid"
    printf 'state   %s\n' "$state"
    printf 'created %s\n\n' "$created"

    proj="$(_claude_project_dir "$path")"; f="$proj/$uuid.jsonl"
    if [[ -f "$f" ]] && _have jq; then
        printf '\033[1mrecent transcript\033[0m\n'
        tail -n 200 "$f" 2>/dev/null | jq -r '
            (.message // {}) as $m
            | ($m.role // .type // empty) as $role
            | ($m.content) as $c
            | ($c
               | if type == "string" then .
                 elif type == "array" then (map(.text // empty) | join(" "))
                 else empty end) as $t
            | select(($role != null) and ($t | length) > 0)
            | "\($role): \($t)"
        ' 2>/dev/null | tail -n 30 | cut -c1-200 || printf '(no transcript preview)\n'
    else
        printf '(no transcript found)\n'
    fi
}

# ── actions ──────────────────────────────────────────────────────────────────

do_jump() {
    local path="$1" session
    session="$(_q '.worktrees[$p].session // empty' --arg p "$path")"
    [[ -n "$session" ]] || return 0
    _have tmux || { printf 'tmux not available\n' >&2; return 0; }
    if tmux has-session -t "$session" 2>/dev/null; then
        tmux switch-client -t "$session"
    elif [[ -d "$path" ]]; then
        tmux new-session -d -s "$session" -c "$path" -n main 2>/dev/null || true
        tmux switch-client -t "$session" 2>/dev/null || true
    else
        tmux new-session -d -s "$session" -n main 2>/dev/null || true
        tmux switch-client -t "$session" 2>/dev/null || true
    fi
}

do_new_branch() {
    local path="$1" main_root br
    main_root="${path%%/.claude/worktrees/*}"
    if [[ ! -d "$main_root" ]]; then
        printf 'repo root not found for this worktree\n' >&2
        _prompt "press enter…" >/dev/null; return 0
    fi
    br="$(_prompt "new branch: ")"
    [[ -n "$br" ]] || return 0
    ( cd "$main_root" && bash "$SCRIPT_DIR/cw" "$br" ) || true
}

do_remove() {
    local path="$1" branch main_root ans
    branch="$(_q '.worktrees[$p].branch // empty' --arg p "$path")"
    main_root="${path%%/.claude/worktrees/*}"
    [[ -n "$branch" ]] || return 0
    ans="$(_prompt "remove '$branch'? [y/N] ")"
    [[ "$ans" == [yY] ]] || return 0
    if [[ -d "$main_root" ]]; then
        ( cd "$main_root" && bash "$SCRIPT_DIR/cw" rm "$branch" ) || true
    else
        # repo gone — just forget it from the manifest.
        cw_wt_remove "$path"
    fi
}

do_edit_note() {
    local path="$1" txt
    txt="$(_prompt "note: ")"
    cw_wt_set_note "$path" "$txt" manual
}

do_gen_note() {
    local path="$1"
    [[ -d "$path" ]] || { printf 'worktree missing\n' >&2; _prompt "press enter…" >/dev/null; return 0; }
    ( cd "$path" && bash "$SCRIPT_DIR/cw" note --gen ) || true
    _prompt "press enter…" >/dev/null
}

do_open_session() {
    local path="$1" uuid="$2" session name pane win newpane
    session="$(_q '.worktrees[$p].session // empty' --arg p "$path")"
    name="$(_q '.worktrees[$p].sessions[$id].name // empty' --arg p "$path" --arg id "$uuid")"
    pane="$(_q '.worktrees[$p].sessions[$id].pane // ""' --arg p "$path" --arg id "$uuid")"
    _have tmux || return 0
    [[ -n "$session" ]] || return 0

    if _pane_alive "$pane"; then
        win="$(tmux display-message -p -t "$pane" '#{window_id}' 2>/dev/null || true)"
        tmux switch-client -t "$session" 2>/dev/null || true
        [[ -n "$win" ]] && tmux select-window -t "$win" 2>/dev/null || true
        tmux select-pane -t "$pane" 2>/dev/null || true
        return 0
    fi

    # Resumable: open a fresh pane in the session and resume the uuid.
    tmux has-session -t "$session" 2>/dev/null || \
        tmux new-session -d -s "$session" -c "$path" -n main 2>/dev/null || true
    if [[ -d "$path" ]]; then
        newpane="$(tmux split-window -t "$session:" -c "$path" -P -F '#{pane_id}' 2>/dev/null || true)"
    else
        newpane="$(tmux split-window -t "$session:" -P -F '#{pane_id}' 2>/dev/null || true)"
    fi
    [[ -n "$newpane" ]] || return 0
    tmux select-pane -t "$newpane" -T "${name:-claude}" 2>/dev/null || true
    if _have claude; then
        tmux send-keys -t "$newpane" "claude --resume $uuid" Enter
    fi
    cw_wt_set_pane "$path" "$uuid" "$newpane"
    tmux switch-client -t "$session" 2>/dev/null || true
}

do_new_session() {
    local path="$1" session branch base name pane uuid
    session="$(_q '.worktrees[$p].session // empty' --arg p "$path")"
    branch="$(_q '.worktrees[$p].branch // empty' --arg p "$path")"
    [[ -n "$session" ]] || return 0
    _have tmux || return 0
    base="$(cw_slug "$branch")"
    name="$(cw_wt_next_session_name "$path" "$base")"
    if _have uuidgen; then
        uuid="$(uuidgen | tr '[:upper:]' '[:lower:]')"
    else
        uuid="$(tr '[:upper:]' '[:lower:]' < /proc/sys/kernel/random/uuid)"
    fi
    tmux has-session -t "$session" 2>/dev/null || \
        tmux new-session -d -s "$session" -c "$path" -n main 2>/dev/null || true
    if [[ -d "$path" ]]; then
        pane="$(tmux split-window -t "$session:" -c "$path" -P -F '#{pane_id}' 2>/dev/null || true)"
    else
        pane="$(tmux split-window -t "$session:" -P -F '#{pane_id}' 2>/dev/null || true)"
    fi
    [[ -n "$pane" ]] || return 0
    tmux select-pane -t "$pane" -T "$name" 2>/dev/null || true
    if _have claude; then
        tmux send-keys -t "$pane" "claude --session-id $uuid --name $name" Enter
    fi
    cw_wt_add_session "$path" "$uuid" "$name" "$pane"
}

# ── fzf loops ────────────────────────────────────────────────────────────────

_have_fzf() { _have fzf; }

L1_HEADER='enter jump · tab drill · ^n new · ^x rm · ^e note · ^g gen · ^r refresh · esc quit'
L2_HEADER='enter open · ^n new session · left/esc back'

level2_loop() {
    local path="$1" rows out key sel uuid
    _have_fzf || { printf 'fzf not installed\n' >&2; _prompt "press enter…" >/dev/null; return 0; }
    while true; do
        rows="$(build_level2_rows "$path")"
        if [[ -z "$rows" ]]; then
            printf 'No Claude sessions in this worktree.\n'
            local ans; ans="$(_prompt "start one now? [y/N] ")"
            [[ "$ans" == [yY] ]] && { do_new_session "$path"; return 0; }
            return 0
        fi
        out="$(printf '%s\n' "$rows" | fzf \
            --delimiter="$TAB" --with-nth=2 --no-multi --ansi \
            --prompt='sessions> ' --header="$L2_HEADER" \
            --expect=enter,left,ctrl-n \
            --preview "bash '$SELF' --preview-session '$path' {1}" \
            --preview-window=right:55%:wrap || true)"
        key="${out%%$'\n'*}"
        sel="$(printf '%s' "$out" | tail -n +2)"
        uuid="${sel%%"$TAB"*}"
        case "$key" in
            enter)  [[ -n "$uuid" ]] && { do_open_session "$path" "$uuid"; return 0; } ;;
            ctrl-n) do_new_session "$path" ;;
            left|"") return 0 ;;
        esac
    done
}

board_loop() {
    local rows out key sel path
    _have_fzf || { printf 'fzf is required for the cw dashboard.\n' >&2; return 1; }

    # Kick a background refresh of any stale PR entries (never blocks the board).
    ( refresh_pr_cache >/dev/null 2>&1 & ) 2>/dev/null || true

    while true; do
        rows="$(build_level1_rows)"
        if [[ -z "$rows" ]]; then
            printf 'No worktrees yet — run `cw <branch>` inside a repo.\n'
            _prompt "press enter to close…" >/dev/null
            return 0
        fi
        out="$(printf '%s\n' "$rows" | fzf \
            --delimiter="$TAB" --with-nth=2 --no-multi --ansi \
            --prompt='worktrees> ' --header="$L1_HEADER" \
            --expect=enter,tab,right,ctrl-n,ctrl-x,ctrl-e,ctrl-g,ctrl-r \
            --preview "bash '$SELF' --preview {1}" \
            --preview-window=right:55%:wrap || true)"
        key="${out%%$'\n'*}"
        sel="$(printf '%s' "$out" | tail -n +2)"
        path="${sel%%"$TAB"*}"
        case "$key" in
            enter)      [[ -n "$path" ]] && { do_jump "$path"; return 0; } ;;
            tab|right)  [[ -n "$path" ]] && level2_loop "$path" ;;
            ctrl-n)     [[ -n "$path" ]] && { do_new_branch "$path"; return 0; } ;;
            ctrl-x)     [[ -n "$path" ]] && do_remove "$path" ;;
            ctrl-e)     [[ -n "$path" ]] && do_edit_note "$path" ;;
            ctrl-g)     [[ -n "$path" ]] && do_gen_note "$path" ;;
            ctrl-r)     ( refresh_pr_cache force >/dev/null 2>&1 & ) 2>/dev/null || true ;;
            "")         return 0 ;;
        esac
    done
}

# ── dispatch ─────────────────────────────────────────────────────────────────

main() {
    case "${1:-}" in
        --preview)          shift; preview_level1 "${1:-}" ;;
        --preview-session)  shift; preview_level2 "${1:-}" "${2:-}" ;;
        --refresh-pr)       shift; refresh_pr_cache "${1:-}" ;;
        --rows)             build_level1_rows ;;          # test hook
        --rows2)            shift; build_level2_rows "${1:-}" ;;  # test hook
        board|"")           board_loop ;;
        *)                  board_loop ;;
    esac
}

main "$@"
