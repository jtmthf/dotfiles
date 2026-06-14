# Code Search & Navigation

Pick the right tool for the question — they don't substitute cleanly for each other:

| Question | Tool |
|---|---|
| Known symbol, import path, or regex | `rg` |
| Cross-file impact / "what calls this" | Serena `find_referencing_symbols` |
| Exact type signature, call hierarchy | LSP `hover`, `incomingCalls`, `outgoingCalls` |
| Concept without a symbol name | `grepai_search` |
| Structural pattern (refactor audits, AST shapes) | `ast-grep` |

Default order on a new question: `rg` first → Serena for impact → LSP for type confirmation → grepai only when you can't name what you're looking for.

## grepai (semantic search)

Available as MCP tools when a project has `.grepai/` initialized. Setup: `grepai init && grepai watch` (uses `nomic-embed-text` via Ollama). Expose via `.mcp.json` at the project root:
```json
{ "mcpServers": { "grepai": { "command": "grepai", "args": ["mcp-serve"] } } }
```

- Confirm the index is live before trusting results — run `grepai status` (CLI). If `grepai watch` isn't running, the index is stale and won't reflect recent edits.
- Score interpretation: ≥0.70 reliable, 0.65–0.70 borderline, <0.65 treat as noise. If everything scores low, try more domain-specific terms ("mutation command handler" over "saved to database") before falling back to `rg`.
- Use `grepai_trace_callers` / `grepai_trace_callees` once you have a symbol name — but watch for name-collision artifacts (e.g. a wrapper and its pure entity sharing a name will appear to call themselves).

## Serena (MCP)

- `find_referencing_symbols` is the highest-leverage tool: returns referencing code with surrounding context grouped by file/symbol kind. Better than raw LSP `findReferences` when you need to reason about impact.
- `get_symbols_overview` is faster than reading a file for orientation.
- Less position-sensitive than LSP — prefer it when you're unsure of exact cursor placement.

## ast-grep (`sg`)

- Start with loose patterns and tighten iteratively. Over-specified patterns silently return zero results rather than degrading — if a match you expect is missing, the pattern is probably too strict on whitespace or AST shape, not actually absent from the code.
- Best for refactor audits and structural invariants ("all functions returning `Result<_, _>`"). Not a replacement for `rg` on simple text searches.

## fd gotcha

Argument order is `fd <pattern> <dir>`, not `fd <dir>`. Passing a bare directory as the first arg silently finds nothing. Use `fd . src/` to enumerate everything under `src/`.
