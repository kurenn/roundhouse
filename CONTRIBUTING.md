# Contributing to Roundhouse

Thanks for your interest. The plugin is a thin layer over Claude Code primitives — the value is in the slim agent contracts, the lazy-loaded references, and the orchestrator's triage logic. Keep contributions focused on those.

## Project structure

- `skills/` — slash-command entrypoints. Each skill is a `SKILL.md` with frontmatter (`name`, `description`) and a workflow body. Keep them under ~100 lines; specialist-mode skills should be near-trivial pointers to the corresponding subagent.
- `agents/` — subagent definitions, one Markdown file per agent. Frontmatter is required: `name`, `description` (quoted if it contains a colon), `tools`, `model`. Keep prompts to ~50 lines of non-negotiables + workflow + output contract. Push depth to `refs/`.
- `refs/` — reference content loaded by agents on demand only. These can be longer (100–300 lines). Each one focuses on a single domain (e.g. `safe-migrations.md`, `n-plus-one.md`).
- `hooks/` — bash scripts run on `PostToolUse`. Keep them stateless, exit-zero unless there's actionable output, filter to the relevant file types internally (no `filePatterns` field — `claude plugin validate` rejects it).

## Validation

Every PR must pass `claude plugin validate <repo-path>`. CI runs this automatically.

```bash
claude plugin validate /path/to/roundhouse
```

## Frontmatter gotchas

- Descriptions with colons MUST be double-quoted: `description: "Foo: bar"` (otherwise YAML drops all frontmatter silently)
- Subagent `model` is `claude-sonnet-4-6` for specialists, `claude-opus-4-8` for orchestrator-style agents
- Hooks JSON nests `hooks: [{type, command}]` arrays under each matcher entry — don't use a flat `command` field

## Adding a new specialist

1. Create `agents/rails-<name>.md` following the existing template (rails-models is a good example to copy)
2. Add at least one reference doc in `refs/` if the domain has tutorial-depth content
3. Add a specialist-mode skill in `skills/rails-<name>/SKILL.md` that points at the agent — **unless the agent is a review gate** (like `rails-database` / `rails-security`), which stay agent-only on purpose. See [DECISIONS.md](DECISIONS.md) (D1) before adding a skill for a gate.
4. Update the orchestrator skill (`skills/rails-feature/SKILL.md`) only if dispatch logic needs to reference the new agent (usually it doesn't — the orchestrator picks dynamically based on the task)
5. Update the README's specialist list (and link any new `refs/` docs from the agent — orphaned refs never get loaded)

## Design decisions

Some choices that look like gaps are deliberate (e.g. why there's no
`/rails-security` skill, why the benchmark isn't re-run on every model bump).
Before "fixing" one, check [DECISIONS.md](DECISIONS.md) — each entry lists the
trigger that would actually justify revisiting it.

## Reporting bugs

Open an issue with:
- The slash command you ran
- The Rails project shape (if relevant)
- What you expected vs what happened
- The session ID if available

## Versioning

Pre-1.0: alpha versions are `1.0.0-alpha.N`. Breaking changes during alpha are expected. Once API stabilizes, drop the alpha suffix and follow SemVer.

## License

By contributing, you agree your contributions will be licensed under the MIT License.
