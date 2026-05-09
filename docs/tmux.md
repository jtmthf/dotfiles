# tmux

`config/tmux/tmux.conf` is symlinked to `~/.config/tmux/tmux.conf`. TPM is cloned into `~/.config/tmux/plugins/tpm/`. Plugins themselves install on first `prefix + I`.

## Prefix

`Ctrl-a` (rebound from `Ctrl-b`).

## Pane / window keys

- `prefix + |` / `prefix + -` — split horizontal / vertical, opens at current pane's path
- `prefix + h/j/k/l` — focus pane left/down/up/right
- `prefix + H/J/K/L` — resize pane (5 cells, repeatable)
- `prefix + T` — set the current pane's title (visible in border, used by Claude to target panes)
- `prefix + S` — convenience 3-pane split (current | top-right / bottom-right). Title each yourself.
- `prefix + r` — reload `tmux.conf`

## Popups

- `prefix + C` — Claude in a 90% popup at the current pane's path
- `prefix + c` — Claude `--continue` (resume most recent session) in popup
- `prefix + g` — Lazygit in popup
- `prefix + \`` — Plain shell scratchpad in popup

## Copy mode

Vi keys. `prefix + Enter` enters copy mode, `v` starts selection, `y` copies to system clipboard via `pbcopy`.

## Theme

Catppuccin Mocha, hand-rolled in `tmux.conf` (no plugin dependency). Status bar shows session name (left) and current branch / user / time / host (right).

## Plugins

Managed by [TPM](https://github.com/tmux-plugins/tpm). `prefix + I` to install, `prefix + U` to update.

| Plugin | Purpose |
|---|---|
| `tmux-sensible` | Sane defaults |
| `tmux-resurrect` | Save/restore — `prefix + Ctrl-s` save, `prefix + Ctrl-r` restore |
| `tmux-yank` | Better clipboard integration |

`@resurrect-capture-pane-contents 'on'` so pane buffers come back on restore.

## `cw` — worktree session per branch

`cw <branch>` creates `~/Worktrees/<repo>/<branch>` (with `git worktree add`) and a tmux session named `<repo>-<branch>` with **one** pane titled `claude`, running Claude Code. Split and title additional panes per-project — there's no fixed `dev`/`test` layout.

```bash
cw my-feature        # create or attach
cw -l                # list
cw -r my-feature     # remove worktree + kill session
```

Override the worktree root with `CW_ROOT` (default `~/Worktrees`).

### Adding panes per project

Inside a `cw` session, lay out the panes you actually want for this project:

```
prefix + S       # convenience: split into 3 panes (claude | two untitled)
prefix + |       # split current pane vertically
prefix + -       # split current pane horizontally
prefix + T       # title the current pane (e.g. server, worker, logs, db, tests)
```

Pane titles show up in the border at the top of each pane. Untitled panes show the hostname — that's your cue to title them. Claude resolves panes by whatever title you give them, so use names that mean something for the project (`server`, `worker`, `e2e`, `psql`, etc.).

## Pane control from Claude

Claude has scoped permissions for `tmux capture-pane`, `tmux send-keys`, and read-side commands (`list-*`, `display-message`, `has-session`). Conventions live in `~/.claude/CLAUDE.md`:

- Resolve a pane by title via `tmux list-panes -F '#{pane_title} #{session_name}:#{window_index}.#{pane_index}'`
- Read with `tmux capture-pane -t <target> -pS -500`
- Run a command with `tmux send-keys -t <target> '<cmd>' Enter`, then poll `capture-pane` for completion (send-keys is fire-and-forget)

If you ask Claude to "watch the server" but no pane is titled `server`, it'll tell you — title a pane first.

## Architecture note

Non-XDG exception departing from `~/.tmux.conf`: tmux 3.1+ supports `~/.config/tmux/tmux.conf` natively.
