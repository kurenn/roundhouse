# Changelog

All notable changes to roundhouse are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] — 2026-06-08

### Added

- **`/rails-jobs` and `/rails-tailwind` specialist-mode skills.** Both shipped as
  agents in 1.0.0 but had no user-facing skill, unlike models / controllers /
  views / services / tests — so they couldn't be invoked directly. All seven
  specialists are now reachable from the slash menu. (`rails-database` and
  `rails-security` remain agent-only — they're orchestrator-invoked gates.)

### Fixed

- **Orphaned reference docs.** `refs/controllers-restful.md` and
  `refs/strong-params.md` both declared "Lazy-loaded by `rails-controllers`" in
  their own headers, but no agent or skill linked them — the model was never
  pointed at them, including the strong-params / mass-assignment guidance. Now
  linked from the `rails-controllers` agent's reference section.
- **Unreferenced examples.** `examples/{trivial,single-domain,cross-cutting}.md`
  existed but nothing pointed to them. The `/rails-feature` triage step now
  references them for tier-boundary cases.

### Changed

- **TDD reminder hook widened.** `check-tdd.sh` now also fires for
  `app/channels`, `app/helpers`, and `lib/` Ruby — previously only
  models / controllers / services / jobs / mailers.
- **Model references refreshed to `claude-opus-4-8`.** `scripts/validate.py`'s
  allowlist accepts the current Opus (alongside the prior `4-7`), and
  `CONTRIBUTING.md` points orchestrator-style agents at it. Historical
  references in `BENCHMARK.md` and the 1.0.0 entry are left as-is — they record
  what was actually used at the time.

## [1.0.2] — 2026-06-08

### Fixed

- **The deterministic hooks never ran.** All three hooks read the edited file
  path from `$CLAUDE_FILE`, an environment variable Claude Code does not set —
  so every hook hit its empty-path guard and exited silently. The advertised
  TDD reminder, migration-safety check, and Rubocop-on-edit gates were inert in
  every install. Hooks now parse the PostToolUse payload Claude Code actually
  delivers on stdin (`.tool_input.file_path`, with a `sed` fallback when `jq`
  is absent). A silent no-op is indistinguishable from success at a glance, so
  this shipped undetected since 1.0.0.
- **Lint hook excluded Rubocop's own bundle group.** `lint-changed.sh` ran
  `BUNDLE_WITHOUT=development bundle exec rubocop`, but Rubocop conventionally
  lives in the `:development` group — so even once the hook fired it failed to
  resolve the gem in the standard Rails layout. Removed the exclusion.

### Added

- **`rails-jobs` and `rails-tailwind` are now reachable.** Both specialists
  shipped in 1.0.0 but the `/rails-feature` orchestrator's implementation step
  never listed them in its dispatch logic, so the planner had no instruction to
  spawn them. Step 5 now enumerates the full roster with explicit spawn triggers
  (async work via `deliver_later`/background processing → `rails-jobs`;
  styling/markup-class work → `rails-tailwind`) and parallelism guidance.
- **Regression guards for the hook payload contract.** `scripts/hook_smoke.sh`
  builds a throwaway Rails-shaped repo, pipes a real PostToolUse payload into
  each hook, and asserts the reminders actually fire — now wired into CI as a
  "Hook behavior" job. `scripts/validate.py` gained a static guard that fails
  any hook expanding `$CLAUDE_FILE` or extracting `file_path` without reading
  stdin. Before/after the fix: `1 passed / 2 failed` → `3 passed / 0 failed`.

## [1.0.1] — 2026-05-05

### Fixed

- Plugin failed to load when installed via marketplace with the error
  "Duplicate hooks file detected: ./hooks/hooks.json resolves to already-loaded
  file." Claude Code auto-loads `hooks/hooks.json` by convention, so the explicit
  `"hooks"` field in `plugin.json` was redundant — `--plugin-dir` accepted the
  duplicate, but marketplace install rejected it. Removed the field.
- Surfaced during smoke-testing the `kurenn/marketplace` install path.

## [1.0.0] — 2026-05-05

First production release. Bench-validated against
[claude-on-rails](https://github.com/kurenn/claude-on-rails) v0.4 across all
three task tiers and 9 specialist domains.

### Bench results — 10 task pairs, sequential interleaved A/B

- **7.8× cheaper overall** ($16.43 plugin vs $128.29 swarm across all 10 tasks)
- **12.2× cheaper, 2.1× faster** averaged across the 9 tasks both systems
  completed
- Plugin completed all 10 tasks; swarm produced no code on T3.4 (heavy
  cross-cutting refactor — architect spent its budget on planning before
  delegating)
- Cost ratios per task ranged from **6.9× to 33.6×** in plugin's favor

See [BENCHMARK.md](BENCHMARK.md) for the full evidence.

### Same as alpha (carried forward)

- Orchestrator skill `/rails-feature` with triage tiers, TDD red/green phase,
  conditional security/database gates
- Bugfix skill `/rails-bugfix` with root-cause discipline
- Specialist-mode skills for models / controllers / views / services / tests
- 9 specialist subagents (Sonnet 4.6): rails-models, rails-controllers,
  rails-views, rails-services, rails-jobs, rails-tests, rails-security,
  rails-database, rails-tailwind
- 11 lazy-loaded reference docs covering ActiveRecord patterns, RESTful
  controllers, strong params, Turbo streams, ViewComponent, safe migrations,
  RSpec patterns, N+1 prevention, CSRF/XSS, SQL injection, Tailwind in Rails
- Three hooks: TDD reminder, migration safety check, Rubocop on edited file
- GitHub Actions workflow

### Architectural decisions (unchanged)

- Single `/prompt-refiner` pass per task, applied at orchestrator level
- Subagents pinned to `claude-sonnet-4-6` via frontmatter `model:` field
- Orchestrator runs on `claude-opus-4-7`
- Hooks filter on file patterns internally (the `filePatterns` field is not
  supported by Claude Code's plugin validator)

## [1.0.0-alpha.1] — 2026-05-04

Initial alpha release. Bench-validated across 3 task tiers in pilot run
(T1.1, T2.2, T3.1). Plugin wins by 14–25× on cost and 2–6× on time across
all pilot tasks.

Renamed from `claude-on-rails-plugin` (the alpha working name) to
`roundhouse`. See README "Why this exists" for the metaphor.
