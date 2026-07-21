# Worktrees (`cw`)

`cw` runs one git worktree per branch, each backed by a dedicated tmux session
holding one or more tracked Claude Code sessions. It turns "work on branch X" into
a single command that creates the worktree, opens a session, launches Claude, and
records everything so a dashboard can show you which agents are waiting on you.

## Mental model

```
branch  ──►  worktree                      ──►  tmux session   ──►  N Claude sessions
feature/x    <repo>/.claude/worktrees/x         <repo>-x            each in its own pane
```

- **One worktree per branch**, at `<repo>/.claude/worktrees/<slug>` (branch name
  slugified — `/` and whitespace become `-`). This is the *same* directory Claude
  Code's native `claude --worktree` uses, so the two interoperate (see below).
- **One tmux session per worktree**, named `<repo>-<slug>` (e.g. `dotfiles-feature-x`).
- **N Claude sessions per worktree** — the first is launched on create; `cw c` adds
  more, each in a new pane. Every session is started with
  `claude --session-id <uuid> --name <name>` so it can be tracked by uuid.

State (notes, session ids, waiting flags) lives under
`${XDG_STATE_HOME:-~/.local/state}/cw`, **not** in the repo.

## Commands

| Command | What it does |
|---------|--------------|
| `cw <branch> [note…]` | Create (or attach) the worktree + session for `<branch>`; launches a tracked Claude session. Optional trailing text becomes the worktree's purpose note. |
| `cw c [label]` | Spawn another Claude session in the current worktree, in a new pane. |
| `cw note [text]` | With no args, print the current worktree's note; with text, set it. |
| `cw note --gen` | Generate the note from the branch diff via `claude -p --model haiku`. |
| `cw ls` | List tracked worktrees (`●` = live tmux session) with branch and note. |
| `cw rm <branch>` | Remove the worktree, kill its session, clear waiting flags, forget it. |
| `cw board` | Open the dashboard popup (also `prefix + w`). |

### Examples

```bash
# Start work on a new branch, with a purpose note
cw feature/onboarding "rework the first-run wizard"

# Branch already exists? Same command just attaches to it
cw feature/onboarding

# Add a second agent alongside the first (e.g. one writes tests, one writes docs)
cw c tests

# Let haiku summarise what the branch is about from its diff
cw note --gen

# See everything you've got going
cw ls

# Tear it all down when the PR is merged
cw rm feature/onboarding
```

## The dashboard (`prefix + w`)

`cw board` (bound to `prefix + w`) opens an fzf popup. It has **two levels**:
level 1 is the worktree board; `tab` drills into the Claude sessions of the
selected worktree.

### Level 1 — the worktree board

One row per tracked worktree, across *all* repos, so you can juggle everything
from one place. Columns:

- **live dot** — `●` if the tmux session exists, dim `○` if not
- **repo / branch**
- **git state** — dirty file count and ahead/behind vs the base branch
  (e.g. `±3 ↑2↓0`); `(missing)` if the worktree dir is gone
- **PR** — open / draft / merged + checks, from a cached `gh` lookup
- **sessions** — `N sess` and, if any are waiting, `N⚠`
- **last activity** — humanised (e.g. `2h`)
- **note**

The preview pane shows `git status -sb`, a capped `git diff --stat` vs base, the
PR title/URL, and the worktree's Claude sessions.

| Key | Action |
|-----|--------|
| `enter` | Jump to the worktree's tmux session (creates it if missing) |
| `tab` | Drill into this worktree's Claude sessions (level 2) |
| `ctrl-n` | New worktree — prompts for a branch, runs `cw <branch>` in that repo |
| `ctrl-x` | Remove the worktree (confirm → `cw rm`) |
| `ctrl-e` | Edit the note |
| `ctrl-g` | Regenerate the note via haiku |
| `ctrl-r` | Refresh (re-reads git + refreshes the PR cache in the background) |
| `esc` | Quit |

### Level 2 — Claude sessions in a worktree

One row per tracked Claude session: its name, a `⚠` if it's waiting on you,
whether it's **live** (its pane still exists) or **resumable** (on disk only),
and last activity. This is the "return to the right session" layer:

| Key | Action |
|-----|--------|
| `enter` | **Live** → jump straight to that pane. **Resumable** → open a new pane in the worktree's session and `claude --resume <uuid>` there. |
| `ctrl-n` | Start a fresh Claude session in this worktree |
| `left` / `esc` | Back to level 1 |

Because every session `cw` launches gets a stable `--session-id`, a resumed
session reconnects to the *same* conversation, and its pane is remembered so the
next jump goes straight to it.

## The sesh popup (`prefix + s`)

`prefix + s` opens a [sesh](https://github.com/joshmedeski/sesh) picker — a
general-purpose fuzzy switcher across tmux sessions and directories. Where
`prefix + w` is worktree-aware, `prefix + s` is the catch-all for jumping to *any*
session or directory. sesh merges in your zoxide history automatically, so
worktree dirs (which `cw` registers with zoxide) show up there too. Config lives
at `config/sesh/sesh.toml`.

## zoxide integration

Every worktree `cw` creates is registered with `zoxide add`, and `cw rm` calls
`zoxide remove`. So after `cw feature/x` you can jump back from anywhere with:

```bash
z x          # or `z feature`, whatever matches the worktree path
```

## The waiting indicator

Claude Code hooks (`scripts/cw/hooks/`) flip a per-session marker under
`$(cw_state_dir)/waiting/<session-uuid>`:

- The **Stop** hook creates the marker when a session finishes its turn and is
  waiting for you, and sets a `@cw_waiting` flag on its tmux window.
- The **UserPromptSubmit** hook clears both when you reply.

Two things surface this:

- **The dashboard** shows, per worktree, how many agents need attention (`N⚠`).
- **The tmux status bar** renders a magenta `⧗` on any window whose Claude
  session is waiting — alongside the existing bell `●` — so you see who's blocked
  on you without opening the board.

The hooks are installed by `install.sh` (merged into `~/.claude/settings.json`
via `merge_claude_settings`) and take effect on your next new Claude session.
They call `cw_set_waiting` / `cw_clear_waiting` in `cw-lib.sh`.

## Where state lives

```
${XDG_STATE_HOME:-~/.local/state}/cw/
├── manifest.json     # worktrees, sessions, notes, tmux session names
├── waiting/          # one empty file per waiting session (presence == waiting)
├── pr-cache.json     # cached PR status for the dashboard
└── .lock             # mkdir-based lock serialising manifest writes
```

The manifest is the source of truth; it's mutated atomically through
`cw_manifest_edit` (jq program → temp file → `mv`) under a coarse lock, so
concurrent `cw`, dashboard, and hook writers don't corrupt it.

## Interop with `claude --worktree`

Claude Code's native `claude --worktree` creates worktrees under the same
`<repo>/.claude/worktrees/` directory. `cw` and native worktrees therefore live
side by side:

- `cw` keeps `/.claude/worktrees/` out of the main checkout's `git status` by
  adding it to `.git/info/exclude` (never a tracked file).
- If a repo has a `.worktreeinclude` file, `cw` replicates Claude Code's behaviour
  and copies the listed gitignored files into each new worktree.
- A worktree made by `claude --worktree` won't be in `cw`'s manifest, so it won't
  appear in `cw ls` / the dashboard until you `cw <branch>` into it (which adopts
  it). Both are just git worktrees underneath.

## Troubleshooting

- **`cw c` says "run from inside a worktree tmux session"** — `cw c` only works
  from within a session `cw` created. `cd` into the worktree (or `z <branch>`) and
  attach first.
- **"current directory isn't a cw worktree"** — you're in a plain checkout or a
  worktree `cw` doesn't track. Run `cw <branch>` from the repo to create/adopt it.
- **`cw note --gen` returns nothing** — needs `claude` on `PATH` and commits on the
  branch to diff against `origin/HEAD`/`main`/`master`. On a fresh branch with no
  commits there's nothing to summarise.
- **Creating a worktree takes forever** — this is almost always the repo's own
  `post-checkout` git hook, not `cw`. `git worktree add` runs a checkout, and a
  fresh worktree has no `node_modules` (git only checks out tracked files), so a
  monorepo hook typically runs a full `pnpm install` + codegen in the new tree.
  The worktree is created quickly; you're waiting on that setup. Let it finish
  before building/running in the worktree.
- **Dashboard says "dashboard not installed"** — `scripts/cw/cw-dashboard.sh` isn't
  executable or is missing. Re-run `./install.sh` (its `setup_cw` chmods the
  scripts).
- **A worktree vanished but still shows in `cw ls`** — the weekly `clean-worktrees`
  maintenance job trashes worktrees that are clean, fully pushed, and idle for 14+
  days (see [Maintenance](maintenance.md)). The manifest entry lingers harmlessly;
  `cw rm <branch>` clears it.
- **Stale waiting flags** — if a session died uncleanly its marker can persist.
  `cw rm <branch>` clears all of a worktree's markers; otherwise delete the file
  under `$(cw_state_dir)/waiting/`.
