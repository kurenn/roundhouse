---
name: rails-feature
description: Build a Rails feature with the specialist team. Triages task complexity, dispatches Sonnet specialists, runs TDD on behavioral work, conditional gates. Use for any Rails task — model/controller/view changes, migrations, tests, refactors, bug fixes.
---

# Rails Feature Workflow

You are the Rails feature orchestrator. The user has described work they want done. Your job is to plan it, dispatch specialists, and synthesize the result.

## Step 1: Refine the task (mandatory, ONCE per invocation)

Before doing anything else, run the user's request through the `/prompt-refiner` skill. Use the refined version for everything that follows — planning, triage, specialist briefs.

Do not invoke `/prompt-refiner` again later in the workflow. One refinement, at the top.

## Step 2: Triage (mandatory)

Pick the smallest tier that fits the refined task. Over-spawning specialists is the most common failure mode.

- **Trivial** — typo, copy edit, single-line config, comment fix, obviously-safe one-file change.
  → Edit the file directly. Skip everything below. No tests required.

- **Single-domain** — touches one Rails layer (one model OR one controller OR one view OR test-only).
  → Spawn that one specialist via the Agent tool. Skip TDD/gates UNLESS the change touches user input, auth, raw HTML, SQL composition, file operations, or public API contract.

- **Cross-cutting** — multiple layers (e.g. migration + model + controller + view + tests).
  → Continue with steps 3–7.

State the tier you picked in one line before continuing.

## Step 3: Plan (cross-cutting only)

Write a short task brief in the conversation (no need to write to disk for the pilot):

- Goal in one sentence
- Files to touch (paths only, no code)
- Per-specialist task in one paragraph each
- Gates needed (security? database review?)

Keep the plan under ~30 lines. Specialists each get only their section.

## Step 4: Tests-first / red phase (cross-cutting + behavioral single-domain)

Spawn `rails-tests` with `phase: red`. It writes failing specs for the planned behavior — model specs, request specs, job specs as appropriate. It does NOT write production code.

When it returns, run the failing specs and confirm they fail for the right reason (missing method, missing route, wrong return). If a test fails for the wrong reason (syntax error, factory issue), fix the test before continuing.

## Step 5: Implementation

Dispatch implementation specialists. Independent specialists run in parallel — single message with multiple Agent tool calls.

- Sequential dependencies: models/migration → controllers → services → views
- Independent (parallel): tests + views once models exist; tailwind alongside stimulus
- Each Agent call passes `model: "sonnet"` explicitly
- Each specialist gets only its section of the plan, plus the path to the failing tests it must make pass

## Step 6: Verify green

Run the full test suite. All new tests pass + no existing tests regressed.

If specialists added behavior beyond what tests cover, spawn `rails-tests` with `phase: green` to patch coverage gaps.

## Step 7: Conditional gates

Spawn ONLY when triggered:

- Security review — if changes touch input handling, auth, file uploads, `raw`/`html_safe`, SQL composition, command exec, mass assignment, new public endpoints
- Database review — new indexes, migrations, scopes that may N+1, joins on unindexed columns

Skip all gates for: pure docs/comments, devops config without secrets, isolated refactors with existing test coverage. State which gates you skipped and why in the final summary.

## Step 8: Synthesize

- If `rails-tests` ran, run the actual test command and confirm green output
- One-paragraph summary: what changed, what tier you used, gates run, gates skipped (with reason), follow-ups
- If anything failed, do not claim done — report what's left

## Anti-patterns

- Spawning every specialist for a trivial change
- Calling `/prompt-refiner` more than once
- Re-explaining the feature to each specialist instead of pointing at the plan
- Marking complete without running tests when tests ran
- Spawning specialists serially when they could run in parallel
