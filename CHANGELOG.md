# Changelog

All notable changes to roundhouse will be documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
once it leaves alpha.

## [1.0.0-alpha.1] — 2026-05-04

Initial alpha release. Bench-validated against claude-on-rails v0.4 across three
task tiers (trivial / single-domain TDD / cross-cutting TDD). Plugin wins by
14–25× on cost and 2–6× on time across all three pilot tasks.

### Added

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
- GitHub Actions workflow validating plugin manifest and shellchecking hooks

### Architectural decisions

- Single `/prompt-refiner` pass per task, applied at orchestrator level
- Subagents pinned to `claude-sonnet-4-6` via frontmatter `model:` field
- Orchestrator runs on `claude-opus-4-7`
- Hooks filter on file patterns internally (the `filePatterns` field is not
  supported by Claude Code's plugin validator)
