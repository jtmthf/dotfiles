# Model Policy

Reference for choosing and escalating models on OpenCode Go. Per-agent assignments live in `opencode.json`; this file holds the constraints behind them.

Read this when picking a non-default model, overriding `/model`, or escalating a tier.

## Caps

OpenCode Go is a single $10/month plan. Each model carries a monthly dollar cap — **$60 / $30 / $15** — with 5-hour = 20% and weekly = 50% sub-caps.

| Cap | Est. requests/mo | Models |
| --- | --- | --- |
| $60 | 6.7k – 150k | `mimo-v2.5` 150k · `deepseek-v4.1-flash` 130k · `glm-5.3-flash` 31.5k · `kimi-k2.7-code` 6.7k |
| $30 | 840 – 27k | `qwen3.8-flash` 27k · `deepseek-v4-flash` · `hy4-preview` · `qwen3.7-max` 840 |
| $15 | 490 – 16.3k | `mimo-v2.5-pro` 16.3k · `deepseek-v4-pro` 5.2k · `glm-5.3` 1.1k · `qwen3.8-max` 810 · `kimi-k3` 490 |

Caps are per model. Spread work across pools — a heavy session on one model hits its 5-hour sub-cap regardless of headroom elsewhere.

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

- **Coder and reviewer come from different families** — `deepseek-v4.1-flash` writes, `kimi-k2.7-code` reviews.
- **`glm-5.3-flash` is the cheap reasoning pool** — DeepSWE v1.1 63 at $0.24/task, and the only model here with a published effort ladder.

## Guardrails

- Muse Spark "Contributor" models train on your prompts — keep private code off them.
- DeepSeek peak pricing on Go: 01:00–04:00 and 06:00–10:00 UTC Mon–Fri; off-peak is 50%.
- Background agents (`compaction` / `title` / `summary`) and `small_model` share the MiMo-V2.5 pool.

## Retired defaults

- `glm-5.2` — same $60 cap as `glm-5.3-flash`, but DeepSWE v1.1 44 vs 63 at ~16x the cost per task ($3.92 vs $0.24).
- `qwen3.7-max` — ~840 req/mo on a $30 cap. Vendor claimed 80.4 SWE-bench Verified; an independent bash-only re-run scored 68.8% (AA Index 29).
