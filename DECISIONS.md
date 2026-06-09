# Design decisions

Short rationale records for choices that look like gaps but are deliberate. The
point is to stop them being re-litigated — if you're about to "fix" one of these,
read the entry first and make sure the listed *revisit trigger* actually fires.

Format: Context → Decision → Why → Revisit when.

---

## D1 — `rails-database` and `rails-security` are agent-only gates, not specialist skills

**Status:** accepted (2026-06-09)

**Context.** Seven specialists have user-invokable skills (`/rails-models`,
`/rails-controllers`, `/rails-views`, `/rails-services`, `/rails-tests`,
`/rails-jobs`, `/rails-tailwind`). Two specialists — `rails-database` and
`rails-security` — exist only as agents the orchestrator dispatches. This looks
asymmetric, and a contributor may be tempted to add `/rails-database` and
`/rails-security` skills "for consistency."

**Decision.** Keep them agent-only. Do **not** add specialist-mode skills for them.

**Why.** Database and security review are *gates*, not authoring modes. They are
meaningful only when there is a concrete change to review — the orchestrator
fires them at the right moment (Step 7 of `/rails-feature`), after specialists
have produced a diff. A user dropping into `/rails-security` in an isolated
session would be reviewing nothing. The clean mental model is **"seven
specialists you direct + two gates the workflow triggers,"** and table symmetry
is not a good enough reason to break it.

**Revisit when.** A user genuinely wants an on-demand security or database pass
over existing code. If so, the right build is **not** a mirror of the specialist
template — it's a skill that takes a diff or path argument and reviews *that*
(e.g. `/rails-security <path-or-diff>`), so the gate still has something to act
on. Treat that as a new feature with its own design, not a consistency fixup.

---

## D2 — The benchmark is a dated 1.0.0 snapshot; don't re-run it reflexively

**Status:** accepted (2026-06-09)

**Context.** `BENCHMARK.md` reports the headline cost/time numbers (6.9×–33.6×
cheaper) from a one-time A/B run on 2026-05-04/05 with the orchestrator on
`claude-opus-4-7`. The orchestrator model has since moved to `claude-opus-4-8`,
so the figures are stamped to an older model.

**Decision.** Leave the numbers as-is. Do **not** re-run the benchmark just
because the model id advanced. The document is explicitly dated and
model-stamped (`BENCHMARK.md` header), so no reader is misled into thinking it's
a current-model measurement.

**Why.** The *claim* is architectural, not model-bound: the cost advantage comes
from doing bulk work on Sonnet and triaging to avoid over-spawning specialists —
that holds regardless of which Opus version orchestrates. A full re-run costs
~$145 and ~70 minutes to refresh a multiplier that is already credible and
honestly caveated. Bad ROI, and the result could be noisier without being more
useful.

**Revisit when** *any* of:
- The orchestration architecture changes materially (triage tiers, dispatch
  logic, refinement strategy) — then the thesis itself is back under test.
- A new `claude-on-rails` (or comparable competitor) version ships and the
  comparison baseline is stale.
- Someone publicly disputes the numbers and a fresh, current-model run is the
  credible response.

When you do re-run, update the `BENCHMARK.md` header dates/model and note the
prior run is superseded — don't silently overwrite the 1.0.0 evidence.
