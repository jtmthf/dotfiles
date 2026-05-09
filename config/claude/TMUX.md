# tmux pane control

Conventions for reading and driving tmux panes from inside a tmux session.

## Precondition

Only run `tmux` commands when `$TMUX` is set. Outside a tmux session there is no server and every `tmux` invocation fails with `no server running`. Check `$TMUX` *in your own logic*, not via inline shell guards — compound commands with brace expansions (`${TMUX:-}`, `||`, `;`) get rejected by the permission matcher.

## Pane naming

Sessions started by the `cw` helper begin with one pane titled `claude` (yours). The user splits and titles additional panes per-project (`server`, `worker`, `logs`, `tests`, etc. — whatever fits the project). Treat pane names as user-provided, not fixed.

## Resolving a pane by name

```bash
tmux list-panes -s -F '#{pane_title} #{session_name}:#{window_index}.#{pane_index}'
```

Each line is `<title> <target>`. Pick the line whose first column matches the name the user gave you (case-insensitive substring is fine), and use the second column as the target.

If the user references a role that doesn't have a pane yet (e.g. "run the tests in a separate pane" but no pane is titled accordingly), tell them and let them create + title the pane — don't speculatively split the layout.

## Reading a pane

```bash
tmux capture-pane -t <target> -pS -500
```

Default `capture-pane` trims trailing blank rows, which can hide whether an interactive widget (Claude prompt, picker, etc.) has rendered yet. To see all rows, pipe through `cat -n` — blank lines show as `   N\t`. If rows past the prompt are blank, the widget genuinely isn't rendered yet.

## Sending input

- **Send text and Enter as two separate calls.** `tmux send-keys -t <target> 'some text' Enter` in one call sometimes drops the Enter when the receiving program is mid-input. Send the text, `capture-pane` to confirm it landed in the input, then send `Enter` in a second call.
- **Wait for the target's prompt before sending.** If you just spawned `claude` (or any TUI) in a pane, your first send-keys may land in the shell that hasn't yet exec'd the program. Poll `capture-pane` for the program's prompt marker (Claude's `❯`, a shell prompt, etc.) before dispatching.
- `send-keys` is fire-and-forget — there's no completion signal. After sending a command, poll `capture-pane` for completion (prompt return, sentinel string, etc.).

## Workflow rules

- For long-running processes (dev servers, watchers, builds), send to a sibling pane rather than blocking your own.
- Never send keys to panes outside the current session unless asked. Never kill panes/windows/sessions you didn't create.
- Keep tmux invocations as **single commands**, not pipelines or `&&`/`||` chains — the permission allow-list matches per command. Run `tmux list-panes` once, parse the result in a follow-up step.
