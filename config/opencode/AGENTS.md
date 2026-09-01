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

## Model usage rules

- Use fast/cheap, high-throughput models (`mimo-v2.5`, `qwen3.8-flash`) for search, mapping, bounded shell/git ops, tests, and background tasks (compaction/titles/summaries).
- Use `glm-5.2` for orchestration-adjacent reasoning: planning, architecture, general research, docs, and as the default/build model — it's the strongest open-weight model on OpenCode Go's standard usage tier.
- Use `qwen3.7-max` for the orchestrator specifically — it benchmarks best for tool-calling/delegation among standard-tier models.
- Use `kimi-k2.7-code` narrowly, for the `coder` and `reviewer` subagents only — it's the strongest model for sustained autonomous coding, but it's also the highest per-message cost, so don't let it become the default for everything.
- Reserve `kimi-k3` (and other restricted-tier models: `glm-5.3`, `glm-5.3-flash`, `qwen3.8-max`, `deepseek-v4-pro`, `mimo-v2.5-pro`) for rare, genuinely hard problems via a manual `/model` override — they sit on OpenCode Go's restricted ~$15/month tier (5-10x fewer included requests than standard-tier models) and burn budget fast even under light use.

Don't run raw `grep`/`find`/broad `read` sweeps yourself when `@explore` would answer faster and keep your own context smaller. Don't fetch external docs yourself when `@scout` can do it in an isolated context. Don't run test suites, git operations, or other bounded shell sequences yourself when `@runner` or `@tester` can do it and report back. Prefer running independent delegations in parallel over sequential ones.
