# Single-domain example — TDD on a model scope

Goal: add a `Post.recent` scope using TDD. The change is scoped to one model and one spec — so single-domain tier with TDD red/green phases, no security/database gates needed.

## Prompt

```
/rails-feature add a Post.recent scope that returns posts created in the last 7 days, ordered newest first. TDD — write the spec first, including a boundary case (a post created exactly 7 days ago should be excluded), then implement.
```

## What roundhouse does

1. Refine via `/prompt-refiner` once
2. Triage → single-domain (one model, one spec, behavioral change → TDD)
3. Spawn `rails-tests` with `phase: red` — writes failing examples
4. Run rspec, confirm 4 examples fail with `NoMethodError: undefined method 'recent'` (right reason)
5. Spawn `rails-models` to implement the scope, pointed at the failing tests
6. Run rspec, confirm all pass
7. Skip security gate (no input handling, no raw SQL, parameterized `?` only)
8. Skip database gate (no new index needed; filtering on `created_at` which is already indexed via Rails defaults)
9. Synthesize with what gates were skipped and why

## Bench result

- Roundhouse: $0.61 in 128s, 4 examples added (positive case, negative case, boundary, ordering), all green
- v0.4 swarm: $10.01 in 278s for the same outcome (5 specialists invoked including devops + security gates that didn't apply)
