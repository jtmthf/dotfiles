# Maintenance

Scheduled jobs that keep the machine from filling up with clutter. They are set
up by `install.sh` (`setup_maintenance`) and run weekly — via **launchd** on
macOS and a managed **crontab** block on Linux/WSL.

## Jobs

| Job | Schedule (Sun) | What it does | Removal |
|-----|----------------|--------------|---------|
| `clean-node-modules` | 03:00 | Trash `node_modules` in projects with no git commit / file activity for `MAINT_NODE_MODULES_MAX_AGE_DAYS` (default 30). | → Trash |
| `clean-worktrees` | 03:30 | Remove git worktrees that are clean **and** fully pushed **and** untouched for `MAINT_WORKTREE_MAX_AGE_DAYS` (default 14). | dir → Trash, then `git worktree prune` |
| `clean-caches` | 04:00 | Prune brew/npm/pnpm/yarn/uv/go caches and Xcode DerivedData via each tool's native command (gated on `command -v`). | deleted outright (regenerable) |
| `empty-trash` | 04:30 | Permanently delete trashed items older than `MAINT_TRASH_RETENTION_DAYS` (default 30). | deleted |

The Sunday times are the *preferred* slot, not the only chance to run — see
[Catch-up](#catch-up) below.

## Catch-up

The schedulers **poll** rather than fire once: launchd runs each agent on the
Sunday slot **and** every ~6 hours (`StartInterval`), and Linux cron runs every
~6 hours. Each job then does real work at most once per `MAINT_MIN_INTERVAL_DAYS`
(default 6), tracked by a timestamp in
`${XDG_STATE_HOME:-~/.local/state}/dotfiles-maint/last-run/<job>`.

This is deliberate: a Mac asleep or powered off at 3 AM Sunday would miss a
plain calendar job, but here the missed run simply happens the next time the
machine is awake and the interval has elapsed. Polls that aren't yet due exit
immediately and write nothing to the logs.

## Safety model

- Anything that could hold work goes to the **Trash** (`trash` on macOS,
  `trash-cli` on Linux) — Finder "Put Back" works, and `empty-trash` only clears
  it after the retention window.
- Worktrees are touched only when git confirms the working tree is clean, an
  upstream exists, and there are no unpushed commits — so nothing local is lost.
- Caches are the one outright-delete, because they self-rebuild. **Docker is
  excluded** (pruning can drop volumes/data); use the `docker-cleanup` shell
  function manually.

## Configuration

Edit `config/maintenance/config.sh` — thresholds and scan roots live there, so
the job scripts never need editing:

```bash
MAINT_SCAN_ROOTS=("$HOME/Projects")
MAINT_NODE_MODULES_MAX_AGE_DAYS=30
MAINT_WORKTREE_MAX_AGE_DAYS=14
MAINT_TRASH_RETENTION_DAYS=30
MAINT_MIN_INTERVAL_DAYS=6      # how often each job actually does work
```

## Running manually / previewing

Every job accepts `--dry-run` to report what it *would* do without changing
anything:

```bash
scripts/maintenance/clean-node-modules.sh --dry-run
scripts/maintenance/clean-worktrees.sh --dry-run
scripts/maintenance/clean-caches.sh --dry-run
scripts/maintenance/empty-trash.sh --dry-run
```

## Logs and notifications

- Logs: `${XDG_STATE_HOME:-~/.local/state}/dotfiles-maint/logs/<job>.log`
  (launchd also writes `<job>.err.log`).
- Notifications: a summary fires after any run that changed something
  (`terminal-notifier` → `osascript` → `notify-send`).

## Managing the schedule

macOS (launchd):

```bash
launchctl list | grep com.jackmoore.maint          # see loaded agents
launchctl bootout gui/$(id -u)/com.jackmoore.maint.clean-caches   # disable one
```

Linux (cron): the block lives between `# >>> dotfiles-maint >>>` markers in
`crontab -e`.

`./install.sh --rollback` removes all agents / the cron block.

## Caveats

- macOS has no reliable "date trashed", so `empty-trash` uses each item's ctime
  (updated when moved into the Trash on the same volume) as a proxy for
  time-in-trash. Linux `trash-cli` uses the exact deletion date.
- Reclaimed-space figures for `clean-caches` are estimates measured across known
  cache directories; `brew cleanup` savings in the Cellar aren't counted.
