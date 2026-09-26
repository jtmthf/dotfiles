---
description: Run a spec-driven-development loop: plan, code, review, test.
agent: orchestrator
subagent: true
---

Run a spec-driven development loop for: $ARGUMENTS

1. Use @explore to map the relevant code.
2. Use @architect to produce a spec if the change is architectural.
3. Delegate independent implementation tasks to @coder.
4. Have @reviewer review each change.
5. Have @tester write/run tests.
6. Use @runner for any git operations (staging, committing, checking status).
7. Integrate results and report the final state.
