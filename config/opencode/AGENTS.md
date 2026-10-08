# Subagent Delegation

Delegate when a task matches one of these:

- **Reconnaissance** — you do not yet know where something lives, or how an unfamiliar area works: `@explore` (say quick / medium / very thorough).
- **External docs** — library, framework, API or dependency behaviour: `@scout`.
- **Tests** — writing or running them: `@tester`.
- **Other shell sequences** — git (`status`/`diff`/`add`/`commit`/`log`), installs, builds, linters: `@runner`.
- **Multi-step or parallelisable work** wider than a search: `@general`.
- **Design** — architecture, API, migration: `@architect`.
- **One bounded coding task from a spec**: `@coder`.
- **Review before merge**: `@reviewer`.
- **Documentation**: `@documenter`.

Read the file yourself when you already know it is the one you will edit; run a single read-only command yourself, and hand over the sequence. For complex features, switch to the `@orchestrator` primary agent. Run independent delegations in parallel.

## Model selection

Per-agent models and effort levels are set in `opencode.json` — read them there. Each agent's system prompt lives in `prompts/<agent>.txt`, referenced from `opencode.json` via `"system": "{file:./prompts/<agent>.txt}"`. There are deliberately no `agents/*.md` files: file-based agent definitions override the `agents` block in `opencode.json`, so a stray markdown file silently wins over this config. Define agents here, not in `agents/`.

Before choosing a non-default model, overriding `/model`, or escalating a tier, read [MODELS.md](MODELS.md) for cap tiers and request budgets, effort-level vocabularies, and the coder/reviewer family rule.
