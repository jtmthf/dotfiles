# Global Instructions

## Communication
- Be concise. No trailing summaries. No emojis.

## Workflow
- Follow a multi-phase order for every task: explore → plan → implement → review → test. Do not skip or collapse phases.
- Use sub-agents for focused, delegated tasks that report a result back.
- Propose agent teams for parallel exploration, independent modules, competing hypotheses, or cross-layer changes. Prefer 3–5 teammates; size tasks as self-contained deliverables.
- Interview in detail until all aspects of a plan are fully resolved before starting implementation. Do not proceed on assumptions.
- If anything doesn't go as expected, stop immediately and clarify next steps before continuing.

## CLI Tooling

Prefer these over GNU defaults:
- `rg` over `grep`, `fd` over `find`, `sd` over `sed`
- `jq` for JSON, `yq` for YAML — prefer over grep/awk pipelines

## On-demand references

Read the relevant file only when the task calls for it:

- [`~/.claude/SEARCH.md`](./SEARCH.md) — code search and navigation (rg, Serena, LSP, grepai, ast-grep, fd)
- [`~/.claude/WEB.md`](./WEB.md) — fetching and researching web pages (crwl, Haiku subagent recipe)
- [`~/.claude/TMUX.md`](./TMUX.md) — driving sibling tmux panes (only when `$TMUX` is set and the user wants cross-pane control)
