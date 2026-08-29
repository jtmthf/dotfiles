# Subagent Delegation

Delegate proactively instead of doing this work yourself when a task matches one of these:

- **Codebase search/exploration** — finding files by pattern, grepping for symbols, or answering "how does X work in this repo": delegate to `@explore`. State a thoroughness level (quick / medium / very thorough) when you call it.
- **External library, framework, API, or dependency research** — docs, version-specific behavior, upstream source, "how does this package work": delegate to `@scout`.
- **Multi-step or parallelizable research/execution** that isn't a narrow file search or doc lookup: delegate to `@general`.

Don't run raw `grep`/`find`/broad `read` sweeps yourself when `@explore` would answer faster and keep your own context smaller. Don't fetch external docs yourself when `@scout` can do it in an isolated context. Prefer running independent delegations in parallel over sequential ones.
