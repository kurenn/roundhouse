# Cross-cutting example — full Comment resource with TDD

Goal: add a `Comment` resource spanning migration, model, controller, routes, views, and specs. Cross-cutting tier — full TDD plus security gate (the change introduces user-input handling and authorization).

## Prompt

```
/rails-feature add a Comment resource. Comments belong to a Post and a User, have a body required between 1 and 10000 chars, are soft-deletable. Add nested routes under posts. Authenticated users only; one user can't delete another user's comment. TDD throughout.
```

## What roundhouse does

1. Refine via `/prompt-refiner` once
2. Triage → cross-cutting (migration + model + controller + routes + views + specs)
3. Plan in 30 lines: files to touch, per-specialist task, gates needed (security yes, database review optional)
4. Spawn `rails-tests` with `phase: red` — writes model spec (associations, validations, soft-delete scope) and request specs (create, destroy, authorization)
5. Run rspec, confirm tests fail
6. Dispatch implementation specialists in parallel where possible:
   - `rails-models` (Comment model + migration)
   - `rails-controllers` (CommentsController + nested routes)
   - `rails-views` (minimal _form + _comment partials)
7. Spawn `rails-tests` with `phase: green` — verify all pass, no regressions
8. Run security review (touches input handling, mass assignment, authorization)
9. Synthesize

## Real pilot run details

The roundhouse run on this exact task:

- Cost: $1.52 / 396s
- Files created: `app/models/comment.rb`, `app/controllers/comments_controller.rb`, `db/migrate/*_create_comments.rb`, `app/views/posts/show.html.erb` (modified), `config/routes.rb` (modified), `spec/models/comment_spec.rb`, `spec/requests/comments_spec.rb`
- 21 spec examples added across model + request specs, all green
- Security review caught a soft-delete bypass in the controller (`set_comment` was scoping through unscoped `@post.comments` instead of `@post.comments.kept`); fixed before declaring done

v0.4 swarm on the same task: $21.93 in 844s, 6 specialists invoked, also correct but 14× more expensive.
