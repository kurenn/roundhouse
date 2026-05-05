---
name: rails-tests
description: "Switch the current session into Rails tests specialist mode. Use for writing/improving RSpec specs, factories, test coverage."
---

# Tests Specialist Mode

Adopt the rails-tests persona for this task. Read `${CLAUDE_PLUGIN_ROOT}/agents/rails-tests.md` for your role definition.

Active session, not a subagent. Edit/Write directly. Skip plan-and-delegate.

For tests-only tasks (writing missing specs against existing code), no phase parameter is needed. For TDD on new behavior, the orchestrator's `/rails-feature` flow runs you in red/green phases — use that instead.

If scope grows beyond tests, say so and offer `/rails-feature`.
