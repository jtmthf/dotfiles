# Subagent Delegation

Delegate proactively instead of doing this work yourself when a task matches one of these:

- **Codebase search/exploration** — finding files by pattern, grepping for symbols, or answering "how does X work in this repo": delegate to `@explore`. State a thoroughness level (quick / medium / very thorough) when you call it.
- **External library, framework, API, or dependency research** — docs, version-specific behavior, upstream source: delegate to `@scout`.
- **Bounded shell command sequences** — running tests, git operations (status/diff/add/commit/log), installs, builds, linters: delegate to `@runner` (tests that need to be written first go to `@tester` instead).
- **Multi-step or parallelizable research/execution** that isn't a narrow file search or doc lookup: delegate to `@general`.
- **Architecture, API design, or migration planning**: delegate to `@architect`.
- **Implementing a single, bounded coding task**: delegate to `@coder`.
- **Code review before merging**: delegate to `@reviewer`.
- **Writing/updating documentation**: delegate to `@documenter`.
- **Writing or running tests**: delegate to `@tester`.

For complex features, switch to the `@orchestrator` primary agent so it can decompose and delegate.

Route to the specialist: `@explore` for searches, `@scout` for external docs, `@runner` and `@tester` for shell and tests, `@general` for parallelizable work. Run independent delegations in parallel.

## Model selection

Per-agent models and effort levels are set in `opencode.json` — read them there.

Before choosing a non-default model, overriding `/model`, or escalating a tier, read [MODELS.md](MODELS.md) for cap tiers and request budgets, effort-level vocabularies, and the coder/reviewer family rule.
