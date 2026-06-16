#!/usr/bin/env bash
# Claude Code status line — two-line prompt.
#
# Reads the session JSON on stdin and prints a colored status line to stdout.
#   Line 1:  model + effort  │  repo + branch + worktree  │  PR (clickable) + CI
#   Line 2:  context pie + % + tokens  │  lines +/-  │  rate limits 5h/7d
#
# Degrades silently when jq / git / gh are unavailable, and never blocks on the
# network: CI status is read from a short-lived cache that is refreshed in the
# background. Deliberately does NOT `set -euo pipefail` or source lib/logging.sh
# — this is a runtime stdout filter; a stray nonzero exit or log line would
# corrupt the rendered bar.

input=$(cat)

# --- colors ---
RESET=$'\033[0m'; DIM=$'\033[2m'
RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
PURPLE=$'\033[35m'; CYAN=$'\033[36m'

# --- nerd-font glyphs (JetBrainsMono Nerd Font) ---
G_REPO=$''    #  repo
G_BRANCH=$''  #  branch
G_TREE=$''    #  worktree / fork
G_PR=$''      #  pull request
G_OK=$''      #  CI pass
G_FAIL=$''    #  CI fail
G_PEND=$''    #  CI pending
G_GAUGE=$''   #  rate-limit gauge

SEP=" ${DIM}│${RESET} "   # group separator
DOT="${DIM}·${RESET}"     # within-group separator

# --- jq-less fallback: print the model name and bail ---
if ! command -v jq &>/dev/null; then
    model=$(printf '%s' "$input" | grep -o '"display_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    printf '%s\n' "${model:-Claude}"
    exit 0
fi

# --- single jq read: one field per line ---
# Each array element is emitted on its own line (empty fields become empty
# lines), so absent values (no PR / worktree / rate limits) stay positional.
# A while-read loop (not `mapfile`) keeps this working on macOS's bash 3.2.
F=()
while IFS= read -r _line; do F+=("$_line"); done < <(printf '%s' "$input" | jq -r '
    [ .model.display_name // "Claude",
      .effort.level // "",
      .workspace.current_dir // .cwd // "",
      (.workspace.repo | if . then "\(.owner)/\(.name)" else "" end),
      .workspace.git_worktree // "",
      (.context_window.used_percentage // -1 | tostring),
      (((.context_window.current_usage.input_tokens // 0)
        + (.context_window.current_usage.cache_read_input_tokens // 0)
        + (.context_window.current_usage.cache_creation_input_tokens // 0)) | tostring),
      (.exceeds_200k_tokens // false | tostring),
      (.cost.total_lines_added // 0 | tostring),
      (.cost.total_lines_removed // 0 | tostring),
      (.pr.number // "" | tostring),
      .pr.url // "",
      .pr.review_state // "",
      (.rate_limits.five_hour.used_percentage // -1 | tostring),
      (.rate_limits.seven_day.used_percentage // -1 | tostring)
    ] | .[]')

model=${F[0]}    effort=${F[1]}     cur_dir=${F[2]}    repo=${F[3]}
worktree=${F[4]} ctx_pct=${F[5]}    ctx_tokens=${F[6]} exceeds=${F[7]}
lines_add=${F[8]} lines_rem=${F[9]} pr_num=${F[10]}    pr_url=${F[11]}
pr_state=${F[12]} rl5=${F[13]}      rl7=${F[14]}

# compact a token count: 156000 -> 156k, 1050000 -> 1.05M
human() {
    local n=${1:-0}
    if [ "$n" -ge 1000000 ] 2>/dev/null; then
        awk -v n="$n" 'BEGIN { printf "%.2fM", n / 1000000 }'
    elif [ "$n" -ge 1000 ] 2>/dev/null; then
        awk -v n="$n" 'BEGIN { printf "%dk", int(n / 1000) }'
    else
        printf '%s' "$n"
    fi
}

# color for a usage percentage: green <70, yellow <90, red otherwise
pct_color() {
    local p=$1
    if [ "$p" -ge 90 ] 2>/dev/null; then printf '%s' "$RED"
    elif [ "$p" -ge 70 ] 2>/dev/null; then printf '%s' "$YELLOW"
    else printf '%s' "$GREEN"; fi
}

# OSC-8 hyperlink: osc_link URL TEXT
osc_link() { printf '\033]8;;%s\007%s\033]8;;\007' "$1" "$2"; }

# ===================== line 1 =====================

# group 1: model + effort
g1="$model"
[ -n "$effort" ] && g1+=" ${DIM}${effort}${RESET}"

# group 2: git (repo / branch / worktree), or bare dir name when not a repo
branch=""
if command -v git &>/dev/null; then
    branch=$(git -C "${cur_dir:-$PWD}" branch --show-current 2>/dev/null)
fi
g2=""
[ -n "$repo" ] && g2+="${CYAN}${G_REPO} ${repo}${RESET}"
if [ -n "$branch" ]; then
    [ -n "$g2" ] && g2+=" "
    g2+="${PURPLE}${G_BRANCH} ${branch}${RESET}"
fi
if [ -n "$worktree" ]; then
    [ -n "$g2" ] && g2+=" "
    g2+="${DIM}${G_TREE} ${worktree}${RESET}"
fi
[ -z "$g2" ] && g2="${CYAN}$(basename "${cur_dir:-$PWD}")${RESET}"

# group 3: PR (clickable, colored by review state) + CI rollup
g3=""
if [ -n "$pr_num" ]; then
    case "$pr_state" in
        approved)          pc=$GREEN ;;
        changes_requested) pc=$RED ;;
        *)                 pc=$YELLOW ;;
    esac
    g3="${pc}$(osc_link "$pr_url" "${G_PR} #${pr_num}")${RESET}"

    # CI: stale-while-revalidate cache, refreshed in the background
    if [ -n "$repo" ] && command -v gh &>/dev/null; then
        cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude"
        mkdir -p "$cache_dir" 2>/dev/null
        cache="$cache_dir/ci-${pr_num}.txt"
        ci_state=""
        [ -f "$cache" ] && ci_state=$(cat "$cache" 2>/dev/null)
        if [ ! -f "$cache" ] || [ -n "$(find "$cache" -mmin +1 2>/dev/null)" ]; then
            ( gh pr checks "$pr_num" -R "$repo" --json bucket 2>/dev/null \
                | jq -r '[.[].bucket] as $b
                    | if   ($b | length) == 0        then "none"
                      elif any($b[]; . == "fail")    then "fail"
                      elif any($b[]; . == "pending") then "pending"
                      else "pass" end' \
                > "${cache}.tmp" 2>/dev/null && mv "${cache}.tmp" "$cache" 2>/dev/null ) &
        fi
        case "$ci_state" in
            pass)    g3+=" ${GREEN}${G_OK}${RESET}" ;;
            fail)    g3+=" ${RED}${G_FAIL}${RESET}" ;;
            pending) g3+=" ${YELLOW}${G_PEND}${RESET}" ;;
        esac
    fi
fi

line1="$g1"
[ -n "$g2" ] && line1+="${SEP}${g2}"
[ -n "$g3" ] && line1+="${SEP}${g3}"

# ===================== line 2 =====================

# context: pie + percent + token count
pie=("○" "◔" "◑" "◕" "●")
if [ -z "$ctx_pct" ] || [ "$ctx_pct" = "-1" ] || [ "$ctx_pct" = "null" ]; then
    ctx="${DIM}○ —${RESET}"
else
    p=${ctx_pct%.*}
    if   [ "$p" -ge 88 ] 2>/dev/null; then idx=4
    elif [ "$p" -ge 63 ] 2>/dev/null; then idx=3
    elif [ "$p" -ge 38 ] 2>/dev/null; then idx=2
    elif [ "$p" -ge 13 ] 2>/dev/null; then idx=1
    else idx=0; fi
    if [ "$exceeds" = "true" ]; then cc=$RED; idx=4; else cc=$(pct_color "$p"); fi
    ctx="${cc}${pie[$idx]} ${p}%${RESET} ${DOT} ${cc}$(human "$ctx_tokens")${RESET}"
    [ "$exceeds" = "true" ] && ctx+=" ${RED}⚠${RESET}"
fi

# churn
churn="${GREEN}+${lines_add:-0}${RESET} ${RED}-${lines_rem:-0}${RESET}"

# rate limits: 5h / 7d (hidden until present)
rl_fmt() {
    local label=$1 pct=$2
    { [ -z "$pct" ] || [ "$pct" = "-1" ] || [ "$pct" = "null" ]; } && return 1
    local p=${pct%.*}
    printf '%s%s %s%%%s' "$(pct_color "$p")" "$label" "$p" "$RESET"
}
rl=""
if rl5s=$(rl_fmt "5h" "$rl5"); then rl+="$rl5s"; fi
if rl7s=$(rl_fmt "7d" "$rl7"); then [ -n "$rl" ] && rl+=" ${DOT} "; rl+="$rl7s"; fi
[ -n "$rl" ] && rl="${DIM}${G_GAUGE}${RESET} ${rl}"

line2="$ctx${SEP}$churn"
[ -n "$rl" ] && line2+="${SEP}${rl}"

printf '%s\n' "$line1"
printf '%s\n' "$line2"
