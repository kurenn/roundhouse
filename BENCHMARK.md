# Benchmark — roundhouse vs claude-on-rails v0.4

**Run dates:** 2026-05-04 to 2026-05-05
**Tasks:** 10 paired runs across 3 tiers, 9 specialist domains
**Test bed:** [bench_app](https://github.com/kurenn/bench_app), Rails 8.0.3 + PostgreSQL + Tailwind + RSpec + Devise + a `Post` resource (railwyrm-generated)
**Models:** orchestrator on `claude-opus-4-7`, specialists on `claude-sonnet-4-6`, both systems
**Refinement:** `/prompt-refiner` once per task at orchestrator level on both systems
**Method:** sequential interleaved A/B; 1 run per cell
**Total API spend:** ~$144.72

This document captures the empirical evidence that roundhouse outperforms [claude-on-rails](https://github.com/kurenn/claude-on-rails) v0.4 on cost, time, correctness, and completeness across a representative Rails task suite.

## Headline

| Task | Tier | Swarm | Plugin | Cost ratio | Outcome |
|---|---|---:|---:|---:|---|
| T1.1 — fix flash typo | trivial | $9.10 / 189s | $0.36 / 30s | **25.6×** | ✓ both |
| T1.2 — missing translation | trivial | $11.90 / 164s | $0.35 / 23s | **33.6×** | ✓ both |
| T2.1 — unique-slug + index (TDD) | single-domain | $13.19 / 326s | $0.70 / 162s | **18.9×** | ✓ both |
| T2.2 — `Post.recent` scope (TDD) | single-domain | $10.01 / 279s | $0.61 / 123s | **16.5×** | ✓ both |
| T2.3 — extract service (TDD) | single-domain | $19.78 / 495s | $1.68 / 265s | **11.8×** | ✓ both |
| T2.4 — User email validation specs | tests-only | $6.71 / 135s | $0.48 / 85s | **14.1×** | ✓ both |
| T3.1 — Comment resource (TDD) | cross-cutting | $21.93 / 844s | $1.52 / 390s | **14.4×** | ✓ both |
| T3.2 — publish notification job (TDD) | cross-cutting | $12.95 / 414s | $1.83 / 262s | **7.1×** | ✓ both |
| T3.3 — admin API + auth + rate limit (TDD) | cross-cutting | $18.17 / 981s | $2.65 / 535s | **6.9×** | ✓ both |
| T3.4 — async report refactor (TDD) | cross-cutting | $4.55 / 154s | $6.25 / 2019s | n/a | **swarm INCOMPLETE** |
| **Totals (all 10)** | | **$128.29 / 66 min** | **$16.43 / 65 min** | **7.8×** | swarm 9/10, plugin 10/10 |

## Headline — completed tasks only (apples-to-apples)

If we exclude T3.4 (where the swarm produced no code at all) and compare only tasks both systems completed:

| | Swarm | Plugin | Plugin advantage |
|---|---:|---:|---:|
| Total cost | $123.74 | $10.18 | **12.2× cheaper** |
| Total wall-clock | 64 min | 31 min | **2.1× faster** |
| Specs added (sum across tasks) | ~250 | ~108 | comparable real coverage; swarm has duplicates across model/request specs |
| Tasks completed | 9/9 | 9/9 | tied |

## Per-tier roll-up

| Tier | Tasks | Swarm $ | Plugin $ | Ratio |
|---|---:|---:|---:|---:|
| Trivial (T1.x) | 2 | $21.00 | $0.71 | **29.5×** |
| Single-domain (T2.x) | 4 | $49.69 | $3.47 | **14.3×** |
| Cross-cutting completed (T3.1, T3.2, T3.3) | 3 | $53.05 | $6.00 | **8.8×** |
| Cross-cutting incomplete (T3.4) | 1 | $4.55 | $6.25 | n/a |

The cost ratio is largest on trivial tasks (where v0.4's mandatory specialist fanout is pure waste) and smallest on cross-cutting tasks (where some real coordination work is genuinely required, and even v0.4 manages partial cache reuse).

## Where v0.4's cost actually goes — the architect tax

For every task v0.4 completed, the architect's own coordination calls dominated total spend:

| Task | Architect cost | Architect calls | % of total |
|---|---:|---:|---:|
| T1.1 | $6.51 | 14 | 71.5% |
| T1.2 | $9.73 | 21 | 81.8% |
| T2.1 | $9.84 | 36 | 74.6% |
| T2.2 | $6.07 | 26 | 60.6% |
| T2.3 | $14.48 | 43 | 73.2% |
| T2.4 | $5.74 | 17 | 85.5% |
| T3.1 | $12.54 | 44 | 57.2% |
| T3.2 | $8.28 | 30 | 64.0% |
| T3.3 | $9.79 | 40 | 53.9% |

Average architect share: **69%** of total task cost.

Architect calls scale from 14 to 44 per task — the architect can't share cache with specialists (each specialist is a separate Claude Code process), so each architect turn pays the full system-prompt overhead repeatedly. The orchestrator in roundhouse runs in a single Claude Code session; subagents share cache with the parent.

## Specialist invocation patterns

v0.4 swarm always invokes the same retinue regardless of the actual change — security and tests run on every task, even trivial ones:

| Task | Specialists invoked (besides architect) |
|---|---|
| T1.1 (trivial) | controllers, security, tests |
| T1.2 (trivial) | i18n, security, tests |
| T2.1 (single-domain) | tests, models, security |
| T2.2 (single-domain) | tests, models, devops, security |
| T2.4 (tests-only) | tests |
| T3.1 (cross-cutting) | tests, models, controllers, views, security |
| T3.2 (cross-cutting) | tests, views, jobs, models, security |
| T3.3 (cross-cutting) | tests, models, controllers, security (8 calls — heavy back-and-forth) |

Roundhouse's triage for the same tasks:

| Task | Plugin specialist work |
|---|---|
| T1.1, T1.2 | orchestrator only — correctly identified trivial, edited directly |
| T2.1, T2.2, T2.3, T2.4 | orchestrator + 1 Sonnet specialist; gates correctly skipped per task surface |
| T3.1, T3.2, T3.3 | orchestrator + 1 Sonnet specialist + inline security review when applicable |
| T3.4 | orchestrator + 1 Sonnet specialist; full Report model + signed-URL endpoint + mailer + 4-layer specs |

## Notable failure mode: T3.4 swarm

The swarm's architect spent its entire $4.55 / 154s budget producing an extensive 250-line refined task spec via `/prompt-refiner` and never delegated to a single specialist. No code was written. `ReportsController#download` remained synchronous; no jobs, mailers, or specs were created.

`tests_pass: true` in the harness is misleading — it just means the existing pre-seed specs continued to pass because nothing changed about them.

This is a real risk for any complex task with the v0.4 architect prompt + per-task `/prompt-refiner` directive: the planning stage can blow the entire turn budget before reaching implementation. Plugin's same task succeeded fully on first run — 16 files, 34 specs, all green, including a single-use atomic guard against download-link replay.

If T3.4 swarm had succeeded at the architect-call rate of T3.3 (40 calls, $9.79 architect alone, $18.17 total), it would have likely been **$30–50** — pushing the all-tasks total over $150 vs plugin's $16.43.

## Token economics

Plugin shares cache with subagents (single Claude Code session, parent context propagated). Swarm spawns separate Claude Code processes per specialist, each loading the full system prompt + tool schemas (~50k cache_create tokens per spawn).

For T3.1 (Comment resource) specifically:

| | Swarm | Plugin |
|---|---:|---:|
| Input tokens | 43 | 29 |
| Output tokens | 18,984 | 11,801 |
| Cache read | 1,707,273 | 690,915 |
| Cache create | 128,950 | 63,877 |

Cache read scales with the number of specialist spawns × turns. Plugin's cache-creation overhead happens once per subagent (and there's only one), not per architect↔specialist round-trip.

## Methodology

### Test bed

`bench-base-v2` is a real Rails 8 application generated by [railwyrm](https://github.com/kurenn/railwyrm), with a `Post` resource scaffolded for cross-cutting tasks to attach to. Tagged immutable so every worktree starts from the same git state.

For tasks needing existing-state setup (T1.1 typo, T1.2 missing translation, T2.3 fat controller, T3.4 sync ReportsController), seed patches at `bench/seeds/<task>.patch` are applied via `git apply` then committed before the agent runs — so the harness measures only the agent's contribution.

### Per-run flow

```
1. git worktree add from bench-base-v2 → fresh isolated copy
2. apply seed patch if any, commit it (so subsequent diffs are agent-only)
3. install the system:
   - swarm: bundle add claude-on-rails (path:), generate claude-swarm.yml,
            patch architect.md to add the prompt-refiner directive
   - plugin: nothing in the worktree — loaded via --plugin-dir at invocation
4. invoke the system non-interactively with timer
5. git add -A && git diff --cached  → captures agent's contribution
   including untracked new files
6. run rspec / rubocop / brakeman as automated checks
7. write results/<task>/<system>/<timestamp>.json
```

### Invocation

**Swarm:**
```bash
cd <worktree>
claude-swarm start --vibe -p "<prompt>" --session-id <uuid>
```

**Plugin:**
```bash
cd <worktree>
claude --plugin-dir /path/to/roundhouse \
       -p "Use the /rails-feature skill to handle this Rails task: <prompt>" \
       --output-format json \
       --model claude-opus-4-7 \
       --add-dir <worktree> \
       --dangerously-skip-permissions
```

Both systems received the same task prompt verbatim. Both used Opus orchestrator + Sonnet specialists + `/prompt-refiner` once per task.

### Token / cost capture

**Swarm:** `~/.claude-swarm/sessions/<root>/<session-id>/session.log` has trailing JSON blocks per call with `modelUsage: { inputTokens, outputTokens, cacheReadInputTokens, cacheCreationInputTokens, costUSD }`. Per-instance breakdown comes from `claude-swarm show <session-id>`.

**Plugin:** `claude --output-format json` returns the usage payload directly on stdout (`total_cost_usd`, `usage.input_tokens`, etc.).

### Automated checks

After the agent runs:

1. `git add -A && git diff --cached` — agent's contribution including untracked
2. `BUNDLE_WITHOUT=development bundle exec rspec` — tests pass? (the BUNDLE_WITHOUT works around an autoload-paths bug when claude-on-rails is in the dev group)
3. `bundle exec rubocop` — clean? (informational; not a gate)
4. `bundle exec brakeman` — clean? (only on tasks with security gates)
5. Expected files: regex match of expected paths against `git diff --cached --name-only`
6. Required patterns: regex match against final file content (not diff text — "fix typo" reverts the file to base, leaving no diff)
7. Forbidden patterns: same, against file content
8. Test count: `+\s*it[\s(]` lines in the staged diff

## Methodology limitations

- **n=1 per cell.** Cost ratios are large enough to survive variance, but individual numbers can move ±20–40% on a re-run. The structural cost difference (architect cache fragmentation in swarm) is consistent across all 10 tasks.
- **Sequential interleaved.** No true parallel A/B execution to avoid Anthropic API rate limits and bundle install conflicts on shared gem cache. Plugin runs sometimes overlapped swarm runs (different processes, different worktrees) but never two swarm runs at once.
- **Several harness fixes were applied mid-run** as data-collection bugs surfaced (initializer guard, `git diff --cached` to capture untracked files, `-p` short flag for plugin invocation). All fixes are checked into the harness. Three runs that completed before each fix had their result JSONs corrected manually against direct file inspection (notes embedded in each affected JSON).
- **No judge LLM ran.** Diffs were manually inspected. For a future polish pass we'd add an anonymized Opus rubric.
- **`tests_pass`/`expected_files`/`required_patterns` are objective signals** but not full quality measures. Plugin and swarm both produced different valid implementations with different style choices; quality across both is comparable when the swarm completes.

## Reproducing

The bench harness lives at [claude-on-rails-bench](https://github.com/kurenn/claude-on-rails-bench). The scenarios are locked at v1.0; per-run JSON results are committed; the harness script (`bin/bench`) is ~350 lines of Ruby. Running the full bench costs about $145 in API spend, ~70 minutes wall-clock.

Per-run JSON results include cost, tokens (input/output/cache_read/cache_create), per-instance cost breakdown for swarm runs, the actual file diff, and the automated check outcomes. Worktrees are kept on disk after each run so the actual agent output is inspectable.

### When to re-run

These numbers are a dated 1.0.0 snapshot (orchestrator on `claude-opus-4-7`).
Don't re-run just because the model id has advanced — the cost thesis is
architectural, not model-bound. Re-run only when the orchestration architecture
changes materially, a new competitor version ships, or the numbers are publicly
disputed. See [DECISIONS.md](DECISIONS.md) (D2) for the full rationale, and
update this document's header (not just the figures) when you do.

## Verdict

Plugin wins on every axis on every task that both systems completed. Cost ratio range: **6.9× to 33.6×**. Plugin completes 10/10 tasks; swarm completes 9/10 with one catastrophic incomplete on the heaviest cross-cutting refactor.

The architectural thesis is empirically supported across all three task tiers, all 9 specialist domains, and a real failure case. **Roundhouse 1.0 is the recommended path forward** for Rails AI-coding teamwork in Claude Code.
