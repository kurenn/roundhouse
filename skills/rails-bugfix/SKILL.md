---
name: rails-bugfix
description: "Diagnose and fix a Rails bug with root-cause discipline. No patches before root cause is identified. Use when given a failing test, stacktrace, log error, or behavioral bug report."
---

# Rails Bugfix Workflow

Iron rule: **no patches before root cause.** If a fix isn't obvious from the error message in 30 seconds, investigate before editing.

## Step 1: Refine the report (mandatory, ONCE per invocation)

Run the user's bug description through `/prompt-refiner`. Use the refined version for all subsequent steps. Do not refine again.

## Step 2: Reproduce

Locate the failing test, log, or stacktrace. If the user didn't provide one, ask for:
- The exact command that fails OR
- The exact stacktrace/error message OR
- The smallest repro steps

Do not start editing without a reproduction. A bug you can't reproduce is a bug you can't verify fixed.

## Step 3: Trace

Read the failure point. Then read the upstream callers. Then read the relevant test (if any). Look at recent commits in the affected area (`git log -p -- <file>`).

## Step 4: Hypothesize

State the suspected root cause in ONE sentence. Be specific: "Y is nil because X#initialize doesn't set it when called from controller#create" — not "there's a nil somewhere."

## Step 5: Verify

Confirm the hypothesis with a targeted read or quick test before editing. Print the value, run the failing case in a console, add a temporary `puts` if necessary. Confirm the cause matches the symptom.

## Step 6: Fix

Smallest patch that addresses the root cause. NO surrounding cleanup, NO refactoring, NO renaming. The bugfix commit should diff-stat to ~5 lines unless the root cause genuinely requires more.

## Step 7: Test

- Run the EXACT failing test that reproduced the bug. Confirm it passes.
- Run the entire spec file. Confirm no regression.
- If the bug shipped without test coverage (which is why it shipped), add the missing regression test that fails before your fix and passes after. Spawn `rails-tests` with `phase: red` for this if helpful.

## Step 8: Synthesize

One paragraph: what was broken, why, what changed, what test now covers it. If you discovered a related issue but didn't fix it, name it explicitly as a follow-up.

## When to spawn specialists

For most bugs: don't. The orchestrator can read and fix directly. Specialists add overhead unless the fix spans layers.

Spawn `rails-security` only if the bug had security implications (data leakage, auth bypass, injection).
Spawn `rails-database` only if the root cause was a query/index/migration issue.

## Anti-patterns

- Patching the symptom instead of the cause
- Adding a try/rescue around the failing line to "make the error go away"
- Changing the test to make it pass
- Marking complete without running the actual repro one more time
