# Changelog

All notable changes to roundhouse are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
