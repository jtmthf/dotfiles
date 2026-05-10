# Web Research

Use `crwl URL -o markdown-fit` to fetch web pages. It strips boilerplate and produces clean, token-efficient markdown — prefer it over WebFetch for any HTML page.

- Default to `-o markdown-fit`; use `-o markdown` only when full content is needed
- Cache is on by default; add `-bc` only when fresh content is required
- For multi-page research: `--deep-crawl bfs --max-pages N`
- Skip `crwl` for raw JSON/API endpoints — use WebFetch directly there

To answer questions about a page without loading it into the primary context window, spawn a Haiku subagent:

```
Run: crwl <url> -o markdown-fit
Then answer from the output only: <question>
```

This is preferred over `-q` for any task requiring precise facts — `-q` offloads to a local Ollama model (granite3.3:2b) which hallucinates on exact figures even when the content is present. Use `-q` only for rough summarisation where precision doesn't matter.
