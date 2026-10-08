# Model Policy

Reference for choosing and escalating models on OpenCode Go Plus. Per-agent assignments live in `opencode.json`; this file holds the constraints behind them.

Read this when picking a non-default model, overriding `/model`, or escalating a tier.

## Caps

Go Plus is one shared $40/month pool: every model draws from the same allowance, and more expensive models consume it faster. Per-request figures are estimates from Go token prices and the documented tokens per request; actual burn varies with request and response length.

| Model | In / Out ($ per 1M tokens) | Est. cost/request |
| --- | --- | --- |
| `longcat-2.5-preview-free` | Free | Free / unlimited |
| `muse-spark-1.3-contributor` | $0.10 / $0.20 | Cheapest per-request class* |
| `mimo-v2.5` | — | Cheap utility; use for background agents |
| `deepseek-v4.1-flash` (off-peak) | $0.15 / $0.60 | $0.00046 |
| `gpt-6-luna` | $0.10 / $0.50 | $0.00071 |
| `deepseek-v4.1-flash` (peak) | $0.30 / $1.20 | $0.00092 |
| `qwen3.8-flash` | $0.15 / $0.47 | $0.00111 |
| `glm-5.3-flash` | $0.15 / $0.50 | $0.0019 |
| `minimax-m2.7` | $0.30 / $1.20 | $0.0035 |
| `kimi-k2.7-code` | — | ~$0.009 estimated (legacy: 6.7k requests on $60) |
| `glm-5.3` | $1.40 / $4.40 | ~$0.014 |
| `qwen3.8-max` | $2.00 / $6.00 | ~$0.019 |
| `kimi-k3` | $3.00 / $15.00 | $0.031 (67× DeepSeek off-peak) |

*Muse Spark trains on prompts; see [Guardrails](#guardrails).

## Effort levels

Each model defines its own vocabulary. Passing a level a model does not define is the common failure.

| Models | Levels | Notes |
| --- | --- | --- |
| `glm-5.3`, `glm-5.3-flash` | `low`, `high`, `max` | No `medium`. Thinking always on. |
| `deepseek-v4.1-flash`, `deepseek-v4-flash` | `low`, `high`, `max` | Default `high`; published benchmarks are at `max`. |
| `deepseek-v4-pro` | `high`, `max` | |
| `qwen3.8-flash` | `none`, `low`, `medium`, `xhigh` | No `high` or `max`. |
| `qwen3.8-max` | `low`, `medium`, `xhigh` | No `none`. |
| `kimi-k3` | `max` | |
| `kimi-k2.7-code` | — | Thinking mandatory. Requesting it disabled routes to K2.6. |

Any model not listed exposes no levels — pass no effort option at all.

Effort levels are largely un-benchmarked outside the GLM family — only `glm-5.3` publishes a ladder (`high` is ~91% of `max` for ~2/3 the output tokens). Treat a low or medium setting as a cost/latency bet rather than a proven quality trade.

## Choosing

- **Keep high-volume roles cheap** — build, coder, general, plan, tester, and orchestrator should use the cheapest capable model. Every 1k requests on `kimi-k3` costs about as much as 16k on `glm-5.3-flash` or 66k on DeepSeek off-peak.
- **Reserve expensive models for low-volume, high-judgment work** — use `glm-5.3` / `max` for architect and `kimi-k2.7-code` for reviewer. Keep coder and reviewer in different families: `deepseek-v4.1-flash` writes, `kimi-k2.7-code` reviews.
- **`kimi-k3` / `max` is escalation-only** for hard reasoning, not overflow for high-volume work.
- **`documenter` runs on `gpt-6-luna`** to minimize burn.

## Guardrails

- Muse Spark "Contributor" trains on your prompts — keep private code off it.
- DeepSeek peak pricing on Go (01:00–04:00 and 06:00–10:00 UTC Mon–Fri) doubles burn versus off-peak.
- Background agents (`compaction` / `title` / `summary`) and `agents.title` use the cheapest utility model, `mimo-v2.5`.

## Retired defaults

- `glm-5.2` — DeepSWE v1.1 44 vs 63 for `glm-5.3-flash`, at ~16× the cost per task ($3.92 vs $0.24).
- `qwen3.7-max` — vendor claimed 80.4 SWE-bench Verified; an independent bash-only re-run scored 68.8% (AA Index 29).
