# Roundhouse

A Claude Code plugin that simulates a Rails development team. Orchestrator on Opus, specialists on Sonnet, prompt-refiner once per task, TDD by default for cross-cutting work, conditional security/database gates.

The orchestrator triages each task into one of three tiers (trivial / single-domain / cross-cutting) and dispatches only the specialists actually needed. Trivial work bypasses the team entirely; cross-cutting work runs tests-first and applies gates only when the change touches their concerns.

> A roundhouse is the rail facility where locomotives are serviced and dispatched onto the right track. Sister tool to [railwyrm](https://github.com/kurenn/railwyrm) (which forges the rail).

## Why this exists

Rails AI-coding tools that fan out specialists for every change waste 60–80% of their cost on the orchestrator chatting with itself. Roundhouse keeps the orchestrator on Opus only when planning is needed, runs specialists on Sonnet when execution is needed, and skips the team entirely for trivial work — measured **7×–34× cheaper** and **2×–7× faster** than the comparable claude-on-rails v0.4 swarm across 10 representative Rails tasks.

See [BENCHMARK.md](BENCHMARK.md) for the full evidence.

## Bench results

10 tasks, 3 tiers, paired runs against [claude-on-rails](https://github.com/kurenn/claude-on-rails) v0.4. Same prompt, same models (Opus orchestrator, Sonnet specialists), same `/prompt-refiner` directive on both sides.

| Task | Tier | v0.4 swarm | Roundhouse | Plugin wins by |
|---|---|---:|---:|---:|
| Fix flash typo | trivial | $9.10 / 3m9s | $0.36 / 30s | **25.6× cheaper, 6.3× faster** |
| Add missing translation | trivial | $11.90 / 2m44s | $0.35 / 23s | **33.6× cheaper, 7.1× faster** |
| Add unique-slug validation + index (TDD) | single-domain | $13.19 / 5m26s | $0.70 / 2m42s | **18.9× cheaper, 2.0× faster** |
| Add `Post.recent` scope (TDD) | single-domain | $10.01 / 4m39s | $0.61 / 2m3s | **16.5× cheaper, 2.3× faster** |
| Extract service object (TDD) | single-domain | $19.78 / 8m15s | $1.68 / 4m25s | **11.8× cheaper, 1.9× faster** |
| Write missing User specs | tests-only | $6.71 / 2m15s | $0.48 / 1m25s | **14.1× cheaper, 1.6× faster** |
| Add Comment resource (TDD) | cross-cutting | $21.93 / 14m4s | $1.52 / 6m30s | **14.4× cheaper, 2.2× faster** |
| Add publish notification job (TDD) | cross-cutting | $12.95 / 6m54s | $1.83 / 4m22s | **7.1× cheaper, 1.6× faster** |
| Add admin API + auth + rate limit (TDD) | cross-cutting | $18.17 / 16m20s | $2.65 / 8m55s | **6.9× cheaper, 1.8× faster** |
| Refactor sync→async report (TDD) | cross-cutting | $4.55 / 2m34s ⚠️ | $6.25 / 33m38s | **swarm shipped no code; plugin shipped 16 files / 34 specs** |
| **Totals (all 10)** | | **$128.29 / 66 min** | **$16.43 / 65 min** | **7.8× cheaper overall** |

⚠️ T3.4 swarm produced an extensive 250-line refined plan via `/prompt-refiner` then ran out of architect budget before delegating to a single specialist. No code was written. The plugin's same task delivered a complete async refactor with single-use signed URLs, an atomic single-use guard, and 34 spec examples.

**Excluding the swarm-incomplete task**, plugin wins by an average of **15.0× on cost** and **2.1× on time** across the 9 tasks both systems completed.

## Install

### Recommended — via the kurenn marketplace

```bash
claude plugin marketplace add kurenn/marketplace   # one-time per user
claude plugin install roundhouse@kurenn            # one-time install
```

Restart your Claude Code session after install and the `/rails-feature`, `/rails-bugfix`, and specialist-mode skills appear in the slash menu.

Pull updates later with:

```bash
claude plugin marketplace update kurenn
claude plugin update roundhouse
```

### Local plugin dir (development / contributing)

```bash
git clone https://github.com/kurenn/roundhouse ~/workspace/roundhouse
claude --plugin-dir ~/workspace/roundhouse
```

## Usage

### Team mode — `/rails-feature`

For any feature work where you want triage + dispatch:

```
/rails-feature add a Post.recent scope returning posts from the last 7 days, ordered newest first
```

The orchestrator runs the prompt through `/prompt-refiner` once, classifies the task into a tier, plans (cross-cutting only), runs TDD red→green for behavioral work, dispatches Sonnet specialists in parallel where possible, and applies conditional gates.

### Specialist mode — when you know the scope

When the task is clearly scoped to one Rails layer and you want to skip orchestration:

- `/rails-models` — ActiveRecord, validations, associations, migrations
- `/rails-controllers` — routes, request handling, strong params
- `/rails-views` — ERB, partials, ViewComponent, Hotwire
- `/rails-services` — service objects, business logic
- `/rails-tests` — RSpec specs, factories, coverage

### Bug fixes — `/rails-bugfix`

Root-cause-first workflow. Reproduces, traces, hypothesizes, verifies, fixes, then writes the missing regression test. Iron rule: no patches before root cause.

## What's in the plugin

```
roundhouse/
├── skills/
│   ├── rails-feature/         orchestrator (team mode)
│   ├── rails-bugfix/          root-cause workflow
│   └── rails-{models,controllers,views,services,tests}/   specialist-mode entrypoints
├── agents/                    9 Sonnet specialists with slim prompts (~50 lines each)
│   ├── rails-models, rails-controllers, rails-views
│   ├── rails-services, rails-jobs, rails-tests
│   ├── rails-security, rails-database
│   └── rails-tailwind
├── refs/                      11 lazy-loaded references — loaded only on demand
│   ├── activerecord-patterns, controllers-restful, strong-params, turbo-streams
│   ├── view-component, safe-migrations, n-plus-one, csrf-xss
│   ├── sql-injection, rspec-patterns, tailwind-rails
└── hooks/
    ├── check-tdd.sh           reminds Claude to write tests before production code
    ├── check-migration.sh     warns on production-risky migration patterns
    └── lint-changed.sh        runs Rubocop on the just-edited Ruby file
```

## Architectural decisions

- **Orchestrator on Opus, specialists on Sonnet.** Opus reasons about how to break the work apart; Sonnet executes the chunks. Cost-aligned to capability.
- **Single `/prompt-refiner` pass at the top.** Refines the user's task once before any planning. Avoids the per-specialist refinement overhead that v0.4 incurs.
- **Triage tiers before dispatch.** Trivial work skips specialists entirely; single-domain spawns one specialist with no auto-gates; cross-cutting runs the full TDD + gates flow.
- **Conditional security/database gates.** Trigger only when the change actually touches input handling, raw HTML, SQL composition, file ops, mass assignment, indexes, or migrations. v0.4 runs every gate on every task; roundhouse runs them when warranted.
- **Slim subagent prompts** (~50 lines) with **lazy-loaded reference docs**. Every specialist loads cheaply; tutorial depth is read on demand only.
- **Hooks for deterministic gates.** TDD reminder, migration safety, Rubocop lint — implemented as zero-token shell scripts that fire on every Edit/Write.

## Migration from claude-on-rails v0.4

If you're currently using the [claude-on-rails](https://github.com/kurenn/claude-on-rails) Ruby gem (v0.4.x) which provides a `claude-swarm`-based Rails team:

1. **Don't immediately remove v0.4.** Roundhouse is a parallel install — both can coexist while you evaluate.
2. **Install roundhouse alongside.** Either via the local-plugin path or the marketplace once available.
3. **Try `/rails-feature` on a low-stakes task** in your Rails project. Compare to your usual v0.4 flow.
4. **Once you're satisfied,** remove the `claude-on-rails` gem from your Gemfile and the `claude-swarm.yml` / `.claude-on-rails/` directory from your project.

The two are functionally similar in coverage but architecturally different — roundhouse uses Claude Code's native Agent tool and skills primitives, where v0.4 spawns separate Claude Code processes coordinated over MCP. The bench shows the practical cost difference.

## Compatibility

- Claude Code 2.69+ (uses `--plugin-dir`, `claude plugin validate`)
- Rails 7.1+ (some references mention Rails 8 features but most apply to 7.x)
- RSpec or Minitest (specialists detect from project shape)
- Ruby 3.2+

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The plugin is a thin layer over Claude Code primitives — keep contributions focused on the slim agent contracts, the lazy-loaded references, and the orchestrator's triage logic.

## License

MIT — see [LICENSE](LICENSE).
