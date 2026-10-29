# Subagent Delegation

Delegate when a task matches one of these:

- **Reconnaissance** — you do not yet know where something lives, or how an unfamiliar area works: `@explore` with `background=true`, asking for the file:line map you need rather than a survey (say quick / medium / very thorough).
- **External docs** — library, framework, API or dependency behaviour: `@scout`.
- **Tests** — writing or running them: `@tester`.
- **Other shell sequences** — git (`status`/`diff`/`add`/`commit`/`log`), installs, builds, linters: `@runner`.
- **Multi-step or parallelisable work** wider than a search: `@general`.
- **Design** — architecture, API, migration: `@architect`.
- **One bounded coding task from a spec**: `@coder`.
- **Review before merge**: `@reviewer`.
- **Documentation**: `@documenter`.

Read the file yourself when you already know it is the one you will edit; run a single read-only command yourself, and hand over the sequence. When `@explore` returns a map, work from it instead of reading the same files again. For complex features, switch to the `@orchestrator` primary agent. Run independent delegations in parallel with `background: true`; use foreground only when your next step needs the result.

## Budget and stopping

These apply to every agent, and above all to subagents, whose step budget is capped in `opencode.json`:

- Return a result before the step budget runs out — on the final step tools are removed and you must summarise.
- If the same command or approach fails twice, stop and report what you tried and the exact error. Do not try it a third time.
- Never run watch modes, dev servers, or interactive commands in the foreground. Use non-interactive flags (`CI=1`, `vitest run`, `--watch=false`) or `background: true`.
- A partial result with a clear "blocked on X" beats continuing to loop. End subagent reports with: Done / Changed / Blocked / Next.

## Model selection

Per-agent models and effort levels are set in `opencode.json` — read them there. Each agent's system prompt lives in `prompts/<agent>.txt`, referenced from `opencode.json` via `"system": "{file:./prompts/<agent>.txt}"`. There are deliberately no `agents/*.md` files: file-based agent definitions override the `agents` block in `opencode.json`, so a stray markdown file silently wins over this config. Define agents here, not in `agents/`.

Before choosing a non-default model, overriding `/model`, or escalating a tier, read [MODELS.md](MODELS.md) for cap tiers and request budgets, effort-level vocabularies, and the coder/reviewer family rule.
