---
name: rails-feature
description: Build a Rails feature with the specialist team. Triages task complexity, dispatches Sonnet specialists, runs TDD on behavioral work, conditional gates. Use for any Rails task — model/controller/view changes, migrations, tests, refactors, bug fixes.
---

# Rails Feature Workflow

You are the Rails feature orchestrator. The user has described work they want done. Your job is to plan it, dispatch specialists, and synthesize the result.

## Step 1: Triage (mandatory)

Pick the smallest tier that fits the task. Over-spawning specialists is the most common failure mode.

- **Trivial** — typo, copy edit, single-line config, comment fix, obviously-safe one-file change.
  → Edit the file directly. Skip everything below. No tests required.

- **Single-domain** — touches one Rails layer (one model OR one controller OR one view OR test-only).
  → Spawn that one specialist via the Agent tool. Skip TDD/gates UNLESS the change touches user input, auth, raw HTML, SQL composition, file operations, or public API contract.

- **Cross-cutting** — multiple layers (e.g. migration + model + controller + view + tests).
  → Continue with steps 2–6.

State the tier you picked in one line before continuing.

For a worked example of each tier — prompt, expected triage, and how the workflow plays out — see `${CLAUDE_PLUGIN_ROOT}/examples/{trivial,single-domain,cross-cutting}.md`. Consult them if a task sits on a tier boundary.

## Step 2: Plan (cross-cutting only)

Write a short task brief in the conversation (no need to write to disk for the pilot):

- Goal in one sentence
- Files to touch (paths only, no code)
- Per-specialist task in one paragraph each
- Gates needed (security? database review?)

Keep the plan under ~30 lines. Specialists each get only their section.

## Step 3: Tests-first / red phase (cross-cutting + behavioral single-domain)

Spawn `rails-tests` with `phase: red`. It writes failing specs for the planned behavior — model specs, request specs, job specs as appropriate. It does NOT write production code.

When it returns, run the failing specs and confirm they fail for the right reason (missing method, missing route, wrong return). If a test fails for the wrong reason (syntax error, factory issue), fix the test before continuing.

## Step 4: Implementation

Dispatch implementation specialists. Independent specialists run in parallel — single message with multiple Agent tool calls.

Available specialists: `rails-models`, `rails-controllers`, `rails-services`, `rails-views`, `rails-jobs`, `rails-tailwind`, `rails-tests`. Spawn `rails-jobs` whenever the feature enqueues async work (mailers via `deliver_later`, background processing, scheduled work); spawn `rails-tailwind` for styling/markup-class work on the views.

- Sequential dependencies: models/migration → controllers → services → views
- Async work: spawn `rails-jobs` once the model/service that enqueues it exists; it can run in parallel with views
- Independent (parallel): tests + views once models exist; `rails-tailwind` alongside `rails-views`
- Specialists carry their own model in frontmatter — don't override it per call

**Each specialist's brief is an ownership contract, not just a task description.** Every brief must state:

- **Files you own (create/edit only these):** the explicit list of paths from the plan, plus the path to the failing tests it must make pass. A unit that will create a file that doesn't exist yet (a new migration, a new spec, a new partial) declares a **directory prefix** (`db/migrate/`) or a **glob** (`spec/models/*_spec.rb`) — you cannot name a filename that hasn't been generated.
- **If the work requires touching a file it does not own, the specialist stops and reports that instead of editing it.**

**Enforce ownership after the wave returns — mechanically, not on trust.** Run `git status --porcelain` and check every changed path against what each specialist declared. Measured (dev-loop 0.2.6 benchmarks): ownership was breached in *every* run, most often by an undeclared new test file — the instruction alone doesn't hold. For anything outside a specialist's declared set: fold it into that specialist's ownership and note the amendment, or revert the file. Don't carry an unexplained file into Step 5 (verify) or Step 6 (gates).

## Step 5: Verify green

Run the full test suite. All new tests pass + no existing tests regressed.

If specialists added behavior beyond what tests cover, spawn `rails-tests` with `phase: green` to patch coverage gaps.

## Step 6: Conditional gates

Spawn ONLY when triggered:

- Security review — if changes touch input handling, auth, file uploads, `raw`/`html_safe`, SQL composition, command exec, mass assignment, new public endpoints
- Database review — new indexes, migrations, scopes that may N+1, joins on unindexed columns

Skip all gates for: pure docs/comments, devops config without secrets, isolated refactors with existing test coverage. State which gates you skipped and why in the final summary.

## Step 7: Synthesize

- If `rails-tests` ran, run the actual test command and confirm green output
- One-paragraph summary: what changed, what tier you used, gates run, gates skipped (with reason), follow-ups
- If anything failed, do not claim done — report what's left

## Anti-patterns

- Spawning every specialist for a trivial change
- Re-explaining the feature to each specialist instead of pointing at the plan
- Marking complete without running tests when tests ran
- Spawning specialists serially when they could run in parallel
