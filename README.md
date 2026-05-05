# Roundhouse

A Claude Code plugin that simulates a Rails development team — orchestrator on Opus, specialists on Sonnet, prompt-refiner once per task, TDD by default for cross-cutting work.

The orchestrator triages each task into one of three tiers (trivial / single-domain / cross-cutting) and dispatches only the specialists actually needed. Trivial work bypasses the team entirely; cross-cutting work runs tests-first and applies conditional security/database review gates.

> A roundhouse is the rail facility where locomotives are serviced, dispatched, and routed onto the right track. Sister tool to [railwyrm](https://github.com/kurenn/railwyrm) (which forges the rail).

## Status

**Alpha (1.0.0-alpha.1).** Bench-validated against [claude-on-rails](https://github.com/kurenn/claude-on-rails) v0.4 across three task tiers — see the pilot results table below. API surface and skill names may still change.

## Pilot bench (vs claude-on-rails v0.4)

| Task | Tier | v0.4 swarm | Roundhouse | Plugin wins by |
|---|---|---|---|---|
| Fix flash typo | trivial | $9.10 · 189s · ✓ correct | $0.36 · 30s · ✓ correct | **25× cheaper, 6× faster** |
| `Post.recent` scope (TDD) | single-domain | $10.01 · 278s · ✓ correct | $0.61 · 128s · ✓ correct | **16× cheaper, 2× faster** |
| `Comment` resource (TDD) | cross-cutting | $21.93 · 844s · ✓ correct | $1.52 · 396s · ✓ correct | **14× cheaper, 2× faster** |
| **Total** | — | **$41.04 · 22 min** | **$2.49 · 9 min** | **16.5× cheaper, 2.4× faster** |

Sample of one run per cell. Both systems use Opus orchestrator + Sonnet specialists + `/prompt-refiner` once per task.

## Install

### As a local plugin (during development)

```bash
git clone https://github.com/kurenn/roundhouse ~/workspace/roundhouse
claude --plugin-dir ~/workspace/roundhouse
```

### As a Claude Code marketplace plugin (once published)

```bash
claude plugin install roundhouse
```

## Usage

### Team mode — `/rails-feature`

For any feature work where you want triage + dispatch:

```
/rails-feature add a Post.recent scope returning posts from the last 7 days, ordered newest first
```

The orchestrator refines the prompt, picks a tier, and runs the appropriate flow.

### Specialist mode

When you know the task is scoped to one Rails layer and want to skip orchestration overhead:

- `/rails-models` — ActiveRecord, validations, associations, migrations
- `/rails-controllers` — routes, request handling, strong params
- `/rails-views` — ERB, partials, ViewComponent, Hotwire
- `/rails-services` — service objects, business logic
- `/rails-tests` — RSpec specs, factories, coverage

### Bug fixes — `/rails-bugfix`

Root-cause-first workflow. Reproduces, traces, hypothesizes, verifies, fixes, then writes the missing regression test.

## What's in the plugin

```
roundhouse/
├── skills/
│   ├── rails-feature/         orchestrator (team mode)
│   ├── rails-bugfix/          root-cause workflow
│   └── rails-{models,controllers,views,services,tests}/   specialist-mode entrypoints
├── agents/
│   ├── rails-models, rails-controllers, rails-views
│   ├── rails-services, rails-jobs, rails-tests
│   ├── rails-security, rails-database
│   └── rails-tailwind         (9 specialists, all on Sonnet 4.6)
├── refs/                      lazy-loaded references — loaded only on demand
└── hooks/
    ├── check-tdd.sh           reminds Claude to write tests before production code
    ├── check-migration.sh     warns on production-risky migration patterns
    └── lint-changed.sh        runs Rubocop on the just-edited Ruby file
```

## Architectural decisions

- **Orchestrator on Opus, specialists on Sonnet** — Opus reasons about HOW to break the work apart; Sonnet executes the broken-down chunks. Cost-aligned to capability.
- **Single `/prompt-refiner` pass at the top** — refines the user task once, not per dispatch. Avoids per-specialist refinement overhead.
- **Triage tiers before dispatch** — trivial work skips specialists entirely; single-domain spawns one specialist with no auto-gates; cross-cutting runs the full TDD + gates flow.
- **Conditional security/database gates** — trigger only when the change actually touches input handling, raw HTML, SQL composition, file ops, mass assignment, indexes, or migrations.
- **Slim subagent prompts** (~50 lines) with **lazy-loaded reference docs** — every specialist loads cheaply; tutorial depth is read on demand only.
- **Hooks for deterministic gates** — TDD reminder, migration safety, Rubocop run as zero-token shell scripts on every Edit/Write.

See [the pilot writeup](https://github.com/kurenn/claude-on-rails/issues) (link TBD) for full benchmark methodology.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
