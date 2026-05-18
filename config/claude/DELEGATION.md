# Haiku Delegation

## When to delegate
- All bash commands, tests, builds, formatters, linters, and code validation go through Haiku subagents.
- Do not run bash directly — Haiku executes, you decide.

## How to delegate
- Describe exactly what to run and what to verify.
- Do not ask Haiku to make design or implementation decisions.
- Batch independent commands into a single subagent call when possible.

## Expected response from Haiku
- Report compactly — omit progress output, repetitive success lines, ANSI noise.
- Always report whether execution succeeded.
- On failure: exit code, key failure reason, exact files and lines.
- Prefer `--quiet` / `-q` / `--short` flags when they still answer the request.
- Never suggest next steps or fixes.
