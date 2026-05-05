# ActiveRecord patterns reference

Lazy-loaded by `rails-models` only when a task needs depth beyond the agent's non-negotiables.

## Modern Rails 7+/8+ features

### normalizes (Rails 7.1+)

Use instead of `before_validation` callbacks. Runs on assignment and works with `find_by`.

```ruby
class User < ApplicationRecord
  normalizes :email, with: -> (email) { email&.strip&.downcase }
end

User.find_by(email: " FOO@BAR.COM ")  # input is normalized automatically
```

### enum with validate (Rails 7.1+)

```ruby
enum :status, { draft: 0, published: 1, archived: 2 }, validate: true
enum :role, { admin: 0, editor: 1, viewer: 2 }, prefix: true  # role_admin?, role_editor?
```

`validate: true` rejects invalid values gracefully instead of raising.

### generates_token_for (Rails 7.1+)

Single-use or expiring tokens that auto-invalidate when relevant attributes change.

```ruby
generates_token_for :password_reset, expires_in: 15.minutes do
  password_salt&.last(10)
end

token = user.generate_token_for(:password_reset)
User.find_by_token_for(:password_reset, token)
```

### Encrypted attributes (Rails 7+)

```ruby
encrypts :ssn, deterministic: false
encrypts :email, deterministic: true  # required to query
```

## Associations

### inverse_of and counter_cache

```ruby
class Post < ApplicationRecord
  belongs_to :user, counter_cache: true, inverse_of: :posts, touch: true
end

class User < ApplicationRecord
  has_many :posts, dependent: :destroy, inverse_of: :user
end
```

`inverse_of` prevents Rails from re-querying when traversing both sides.
`counter_cache: true` requires a `posts_count` integer column on users.
`touch: true` updates `user.updated_at` when a post is saved.

### dependent strategies

| Strategy | Effect |
|---|---|
| `:destroy` | Calls `destroy` on each child (runs callbacks) |
| `:delete_all` | SQL DELETE, no callbacks (faster, riskier) |
| `:nullify` | Sets foreign key to NULL |
| `:restrict_with_error` | Adds an error if children exist |
| `:restrict_with_exception` | Raises if children exist |

Default `:destroy` unless you have a specific reason.

## Scopes

### Lambdas, not class methods, for parameter capture

```ruby
# GOOD
scope :recent, ->(days = 7) { where("created_at > ?", days.days.ago) }
scope :by_status, ->(status) { where(status: status) }

# Avoid: class methods that look like scopes (lose chainability nuances)
def self.recent
  where("created_at > ?", 7.days.ago)
end
```

### Avoid default_scope

`default_scope` silently affects EVERY query — including counts, joins, validations. Hard to override. Use named scopes that callers opt into.

## Validations

### Database-backed uniqueness

Always pair `validates :x, uniqueness: true` with a unique index in the migration. Without the index, race conditions create duplicates.

```ruby
# Model
validates :slug, uniqueness: { case_sensitive: false }

# Migration
add_index :posts, "lower(slug)", unique: true, name: "index_posts_on_lower_slug"
```

### Conditional validation

```ruby
validates :phone, presence: true, if: -> { wants_sms? }
validates :address, presence: true, on: :create
```

## Callbacks

### after_commit, not after_save

`after_save` fires inside the transaction — if the transaction rolls back, your side effect already happened. `after_commit` fires only on successful commit.

```ruby
after_commit :notify_subscribers, on: :create
after_commit :invalidate_cache, on: [:update, :destroy]
```

### Callback discipline

- More than 3 callbacks on a model is a smell — extract to a service object
- `after_initialize`, `before_validation` for attribute defaults — but prefer `normalizes` for cleaning
- Never use callbacks for cross-aggregate writes (e.g. updating another model's count). Use service objects.

## Query optimization

### find_each / in_batches

```ruby
User.find_each(batch_size: 1000) do |user|
  user.recompute_score!
end

User.in_batches(of: 500) do |relation|
  relation.update_all(active: false)
end
```

### preload / includes / eager_load

| Method | Strategy |
|---|---|
| `includes` | Lets Rails decide (preload or eager_load) |
| `preload` | Always two queries (no JOIN) |
| `eager_load` | Always JOIN (one query) |

Use `includes` by default. Use `preload` when you don't need to filter on the joined table. Use `eager_load` when you need to filter on the joined table.

### strict_loading

```ruby
class Post < ApplicationRecord
  has_many :comments, strict_loading: true
end

# Now post.comments raises if it triggers an N+1
```

## Migrations

### Reversibility

Every migration must be reversible. Test with `bin/rails db:migrate:redo` before commit.

```ruby
# Reversible by default
class AddSlugToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :slug, :string
    add_index :posts, :slug, unique: true
  end
end

# Use up/down for non-reversible operations
class BackfillSlugs < ActiveRecord::Migration[8.0]
  def up
    Post.where(slug: nil).find_each { |p| p.update!(slug: p.title.parameterize) }
  end

  def down
    # Backfill is irreversible
  end
end
```

### Zero-downtime migrations

- Adding columns is safe
- Adding NOT NULL with a default may rewrite the table on Postgres before 11 — use `add_column ..., default: ...` (which Postgres 11+ handles in metadata only)
- Removing columns: deploy code that ignores them first, THEN remove
- Renaming columns: same, deploy aliases first
- Adding indexes on Postgres: use `algorithm: :concurrently` and `disable_ddl_transaction!`

```ruby
class AddIndexConcurrently < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :posts, :user_id, algorithm: :concurrently
  end
end
```
