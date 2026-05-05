# Trivial example — a one-line fix

Goal: fix a typo in a flash message. The orchestrator should recognize this as trivial-tier and edit directly without spawning specialists or running gates.

## Prompt

```
/rails-feature there's a typo in PostsController#create — the flash message says "sucessfully" instead of "successfully". fix it.
```

## What roundhouse does

1. Refine via `/prompt-refiner` (one line in, one line out for trivial tasks)
2. Triage → trivial
3. Edit `app/controllers/posts_controller.rb` directly
4. Synthesize: "Fixed. Trivial tier; no specialists, tests, or gates needed."

## What v0.4 swarm did with the same prompt

(For comparison, from the bench pilot.)

- Architect made 14 turns coordinating
- Spawned controllers + security + tests specialists for the one-character fix
- $9.10 in 189 seconds

## What roundhouse did

- Orchestrator made one turn
- No specialists spawned
- $0.36 in 30 seconds

Same outcome, 25× less spend.
