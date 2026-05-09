# Global Instructions

## Communication
- Be concise. No trailing summaries. No emojis.

## Workflow
- Follow a multi-phase order for every task: explore → plan → implement → review → test. Do not skip or collapse phases.
- Use sub-agents for focused, delegated tasks that report a result back.
- Propose agent teams for parallel exploration, independent modules, competing hypotheses, or cross-layer changes. Prefer 3–5 teammates; size tasks as self-contained deliverables.
- Interview in detail until all aspects of a plan are fully resolved before starting implementation. Do not proceed on assumptions.
- If anything doesn't go as expected, stop immediately and clarify next steps before continuing.

## Web Research

Use `crwl URL -o markdown-fit` to fetch web pages. It strips boilerplate and produces clean, token-efficient markdown — prefer it over WebFetch for any HTML page.

- Default to `-o markdown-fit`; use `-o markdown` only when full content is needed
- Use `-q "question"` to get a focused answer without loading the full page into context
- Cache is on by default; add `-bc` only when fresh content is required
- For multi-page research: `--deep-crawl bfs --max-pages N`
- Skip `crwl` for raw JSON/API endpoints — use WebFetch directly there

## Semantic Code Search

When a project has grepai initialized (`.grepai/` exists and `grepai watch` is running), MCP tools are available:
- Use `grepai_search` when you don't know the symbol name ("how is rate limiting enforced", "where is auth checked")
- If you can guess a method name or pattern, use ripgrep directly — it will be faster and more precise
- Scores below ~0.70 mean nothing rose above noise; try domain-specific terms (e.g. "mutation command handler" over "saved to database") or fall back to grep
- Use `grepai_trace_callers` / `grepai_trace_callees` once you have a known symbol to map call paths
- Check `grepai_index_status` first to confirm the index is live

Per-project setup: `grepai init && grepai watch` (uses `nomic-embed-text` via Ollama, `gob` file store by default). Add `.mcp.json` at the project root to expose the MCP tools:
```json
{ "mcpServers": { "grepai": { "command": "grepai", "args": ["mcp-serve"] } } }
```

## tmux

If `$TMUX` is set and the user wants you to read or drive sibling panes (capture output, send commands, watch a server, etc.), read `~/.claude/TMUX.md` first for the conventions and gotchas. Otherwise ignore tmux entirely.
