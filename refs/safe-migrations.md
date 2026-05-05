# Safe migrations reference

Lazy-loaded by `rails-models` and `rails-database` when migration safety needs depth.

The goal: every migration is reversible AND deployable to production without taking the app down.

## The reversibility checklist

Every migration must:
- Use `change` if the operation is auto-reversible, or `up`/`down` if not
- Pass `bin/rails db:migrate:redo` (down + up) before commit
- Not leave the database in a half-migrated state if it fails partway

```ruby
# Auto-reversible: add_column, add_index, create_table, add_reference, etc.
class AddSlugToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :slug, :string
    add_index :posts, :slug, unique: true
  end
end

# Not auto-reversible: data backfill, complex transforms
class BackfillSlugs < ActiveRecord::Migration[8.0]
  def up
    Post.where(slug: nil).find_each { |p| p.update!(slug: p.title.parameterize) }
  end

  def down
    # Backfill is irreversible by design — don't pretend
  end
end
```

## Zero-downtime patterns

### Adding a column with NOT NULL

The naive approach fails on existing rows:

```ruby
# BAD: fails on Postgres for any populated table
add_column :posts, :status, :integer, null: false
```

Postgres 11+ handles `default:` in metadata only (no table rewrite):

```ruby
# GOOD on Postgres 11+
add_column :posts, :status, :integer, null: false, default: 0
```

For older Postgres or for backfilling existing data with computed values, split across deploys:

```ruby
# Deploy 1: add column nullable, backfill in a separate migration
class AddStatusToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :status, :integer
  end
end

class BackfillPostStatus < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    Post.in_batches.each_record { |p| p.update_column(:status, p.published_at? ? 1 : 0) }
  end

  def down
    # irreversible
  end
end

# Deploy 2: enforce NOT NULL after data is populated
class EnforcePostStatusNotNull < ActiveRecord::Migration[8.0]
  def change
    change_column_null :posts, :status, false
  end
end
```

### Adding indexes (Postgres)

A normal `add_index` locks the table. For production tables of any size, use:

```ruby
class AddIndexToPostsSlugConcurrent < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :posts, :slug, unique: true, algorithm: :concurrently
  end
end
```

`disable_ddl_transaction!` is required — concurrent indexes can't run inside a transaction.

### Removing a column

The naive approach breaks the running app between deploys (the old code still references the column):

```ruby
# BAD: app crashes if old pods are still running
remove_column :posts, :legacy_status, :integer
```

Multi-deploy safe pattern:

```ruby
# Deploy 1: tell Rails to ignore the column (still in DB)
class Post < ApplicationRecord
  self.ignored_columns += ["legacy_status"]
end

# Deploy 2: drop the column AFTER deploy 1 is fully rolled out
class RemovePostLegacyStatus < ActiveRecord::Migration[8.0]
  def change
    remove_column :posts, :legacy_status, :integer
  end
end

# Deploy 3: remove the ignored_columns line
```

### Renaming columns / tables

Same as remove — `rename_column` is a destructive operation from the running app's perspective. Multi-deploy:

1. Add new column, backfill, dual-write (model writes both old and new)
2. Switch reads to new column
3. Remove old column

In practice: avoid renames. Add a new column, migrate code to the new column, leave the old column ignored.

### change_column

```ruby
change_column :posts, :status, :string  # may rewrite the entire table
```

For large tables, split across migrations: add new column → backfill → switch → drop old.

## Migration anti-patterns

- `Post.update_all(...)` in a migration that calls model code — model definitions change over time, and the migration breaks when re-run on a snapshot
- `Post.find_each { |p| p.update!(...) }` without `disable_ddl_transaction!` and `in_batches` — long transaction
- A single migration that does multiple risky things — split for easier rollback
- `add_foreign_key` without `validate: false` on populated tables — long lock; split into add-then-validate
- Schema changes outside of migrations (manual ALTER TABLE) — `db/schema.rb` drifts from reality

## Useful gems

- `strong_migrations` — fails the migration if it detects a known unsafe pattern, with the safe rewrite suggested
- `active_record-postgres_enum` — type-safe enums via Postgres ENUM type
