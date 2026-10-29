# Model Policy

Reference for choosing and escalating models on OpenCode Go Plus. Per-agent assignments live in `opencode.json`; this file holds the constraints behind them.

Read this when picking a non-default model, overriding `/model`, or escalating a tier.

## Caps

Go Plus is one shared $40/month pool: every model draws from the same allowance, and more expensive models consume it faster. Cost per task is Artificial Analysis's measured cost to run its Intelligence Index; actual burn varies with request and response length.

| Model | In / Out / Cache read ($ per 1M) | AA cost/task | Terminal-Bench 4.0 | AA Coding Agent Index |
| --- | --- | --- | --- | --- |
| `mimo-v2.6-flash` | $0.14 / $0.28 / $0.0028 | $0.13 | 22.7 | — |
| `glm-5.3-flash` | $0.15 / $0.50 / $0.03 | — | 32.8 | — |
| `deepseek-v4.1-flash` `#max` | $0.15 / $0.60 / $0.003 (off-peak) | $0.60 | 33.8 | 46–47 |
| `glm-5.3` `#max` | $1.40 / $4.40 / $0.26 | $5.01 | 41.9 | 48.9 (in opencode) |
| `kimi-k3.1-pro` | $2.00 / $10.00 / $0.20 | $3.68 | 67.2 | — |

`kimi-k3.1-pro` beats `glm-5.3`, `gemini-4-argon`, `qwen3.8-max` and `grok-4.7` on both score and cost per task, so those are not used.

## Tiers

- **Judgment** — `kimi-k3.1-pro` for plan, orchestrator, architect, reviewer. Low volume, and mistakes here compound. If the pool runs short, move orchestrator to `glm-5.3#high` first.
- **Workhorse** — `deepseek-v4.1-flash#max` for build, coder, general, tester. Coder and reviewer stay in different families.
- **Light** — `glm-5.3-flash#high` for explore, scout, runner, documenter.
- **Background** — `mimo-v2.6-flash` for compaction, title, summary. These are single tool-less calls, so its tendency to loop does not apply.

## Effort levels

Each model defines its own vocabulary. Passing a level a model does not define is the common failure.

| Models | Levels | Notes |
| --- | --- | --- |
| `glm-5.3`, `glm-5.3-flash` | `low`, `high`, `max` | No `medium`. Thinking always on. `high` is ~91% of `max` for ~2/3 the output tokens. |
| `deepseek-v4.1-flash` | `low`, `high`, `max` | Default `high`; published benchmarks are at `max`. |
| `deepseek-v4-pro` | `high`, `max` | |
| `qwen3.8-flash` | `none`, `low`, `medium`, `xhigh` | No `high` or `max`. |
| `qwen3.8-max` | `low`, `medium`, `xhigh` | No `none`. |
| `kimi-k3` | `max` | |

Any model not listed, including `kimi-k3.1-pro` (thinking always on), exposes no levels — pass no effort option at all.

## Guardrails

- Subagent runaway loops are bounded by `steps` in `opencode.json` and the stopping rules in `AGENTS.md`. Keep both when adding an agent.
- MiMo models loop in agentic use; keep them off tool-using agents.
- Muse Spark "Contributor" models train on your prompts — keep private code off them.
- DeepSeek peak pricing on Go (01:00–04:00 and 06:00–10:00 UTC Mon–Fri) doubles burn versus off-peak.

## Retired defaults

- `glm-5.2` — DeepSWE v1.1 44 vs 63 for `glm-5.3-flash`, at ~16× the cost per task ($3.92 vs $0.24).
- `qwen3.7-max` — vendor claimed 80.4 SWE-bench Verified; an independent bash-only re-run scored 68.8% (AA Index 29).
- `mimo-v2.5` — most frequent source of stuck subagent loops.
- `gpt-6-luna` — Terminal-Bench 4.0 below 9 at every effort under `max`.
