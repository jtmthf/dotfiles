# Claude Code Status Line

A two-line custom status line for Claude Code, rendered by
[`config/claude/statusline.sh`](../config/claude/statusline.sh).

Claude Code runs the script after each assistant message (and every
`refreshInterval` seconds), piping the session state to it as JSON on stdin.
The script prints the bar to stdout. It requires `jq`; `git` and `gh` are
optional and their segments are omitted when missing.

## Layout

```
Opus  high │  owner/repo   main   feature-x │  #1234 
◕ 78% · 156k │ +156 -23 │  5h 23% · 7d 41%
```

Groups are separated by a dim `│`; items within a group by a dim `·`.

### Line 1 — identity & location

| Segment   | Source                     | Notes                                                         |
| --------- | -------------------------- | ------------------------------------------------------------- |
| Model     | `model.display_name`       | Always shown.                                                 |
| Effort    | `effort.level`             | Dim; only when the model exposes reasoning effort.            |
| Repo     | `workspace.repo`           | `owner/name`, cyan. No subprocess — comes from stdin.         |
| Branch   | `git branch --show-current`| Purple. The only subprocess the script runs.                  |
| Worktree | `workspace.git_worktree`   | Dim; only inside a linked git worktree.                       |
| PR       | `pr.{number,url,review_state}` | Clickable (OSC-8). Glyph colored: green=approved, red=changes requested, yellow=pending. |
| CI        | `gh pr checks` (cached)    | `=pass =fail =pending`. See caching below.                 |

When the directory is not a git repo, line 1 falls back to the directory
basename and the git/PR/CI segments are omitted.

### Line 2 — live usage

| Segment      | Source                                  | Notes                                                             |
| ------------ | --------------------------------------- | ----------------------------------------------------------------- |
| Context pie  | `context_window.used_percentage`        | `○◔◑◕●` by fill. Green <70%, yellow <90%, red ≥90%. `○ —` before the first API call / after `/compact`. |
| Token count  | `context_window.current_usage.*`        | Compact (`156k`, `1.05M`). Sum of input + cache read + cache creation. |
| Overflow     | `exceeds_200k_tokens`                   | Forces red `●` and appends `⚠` (fires on the 1M-context model).   |
| Churn        | `cost.total_lines_{added,removed}`      | `+added` green, `-removed` red.                                   |
| Rate limits  | `rate_limits.{five_hour,seven_day}`     | `5h%` / `7d%`, colored by usage. Hidden until the first API response. |

## CI caching (stale-while-revalidate)

`gh pr checks` is a network call, so it is never run inline. The script reads
the last result from `${XDG_CACHE_HOME:-~/.cache}/claude/ci-<pr>.txt` and
renders it instantly. If that file is older than ~60s it kicks off a detached
background `gh` refresh whose result is picked up on the next tick. Pair with
`refreshInterval` (set to `10` in settings) so it self-updates between messages.

## Configuration

The `statusLine` block lives in
[`config/claude/settings.json`](../config/claude/settings.json) (the shareable
baseline that `install.sh` jq-merges into `~/.claude/settings.json`):

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline.sh",
  "padding": 0,
  "refreshInterval": 10
}
```

`install.sh`'s `setup_claude()` symlinks the script to `~/.claude/statusline.sh`
and marks it executable. Disable at any time with `/statusline delete`.

## Testing

Pipe a sample payload into the script:

```bash
echo '{
  "model": { "display_name": "Opus" },
  "effort": { "level": "high" },
  "workspace": { "current_dir": ".", "repo": { "owner": "acme", "name": "app" } },
  "context_window": {
    "used_percentage": 78,
    "current_usage": { "input_tokens": 150000, "cache_read_input_tokens": 6000 }
  },
  "cost": { "total_lines_added": 156, "total_lines_removed": 23 }
}' | ~/.claude/statusline.sh
```
