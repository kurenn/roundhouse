# N+1 queries reference

Lazy-loaded by `rails-database` and `rails-models` when query performance needs depth.

An N+1 happens when iterating a collection triggers one query per item:

```ruby
# Bad: 1 + N queries
@posts = Post.all
@posts.each { |p| puts p.user.email }  # one User query per post
```

## Fix: preload / includes / eager_load

```ruby
@posts = Post.includes(:user)        # smart: lets Rails decide
@posts = Post.preload(:user)         # always two queries (no JOIN)
@posts = Post.eager_load(:user)      # always one JOIN query
```

| Method | Strategy | Use when |
|---|---|---|
| `includes` | Lets Rails decide | Default — Rails picks based on whether you reference the joined table |
| `preload` | Always two queries (no JOIN) | You don't filter on the joined table; want simpler SQL |
| `eager_load` | Always one JOIN query | You need to `where` or `order` on the joined table |

```ruby
# preload — joined table not used in WHERE
Post.preload(:user).where(status: :published)

# eager_load — joined table IS used in WHERE
Post.eager_load(:user).where(users: { admin: true })

# includes picks based on the WHERE
Post.includes(:user).where(users: { admin: true })  # uses eager_load
Post.includes(:user).where(status: :published)      # uses preload
```

## Nested associations

```ruby
# Single-level
Post.includes(:user)

# Nested
Post.includes(user: :organization)

# Multiple
Post.includes(:user, :tags, comments: :user)
```

## strict_loading — fail fast

Marks an association so any access without preloading raises:

```ruby
class Post < ApplicationRecord
  has_many :comments, strict_loading: true
end

post.comments  # raises ActiveRecord::StrictLoadingViolationError if not preloaded

# Per-record
post = Post.strict_loading.first
post.comments  # raises
post.user      # raises

# Per-association in includes
Post.includes(:comments).strict_loading
```

Production rollout: enable for new associations first; gradually expand.

## Counter caches

Avoid `posts_count = posts.count` per record:

```ruby
class Comment < ApplicationRecord
  belongs_to :post, counter_cache: true
end
```

Migration:

```ruby
add_column :posts, :comments_count, :integer, default: 0, null: false
# Backfill
Post.find_each { |p| Post.reset_counters(p.id, :comments) }
```

## Bullet gem

Detects N+1 in development:

```ruby
# config/environments/development.rb
config.after_initialize do
  Bullet.enable = true
  Bullet.alert = true
  Bullet.bullet_logger = true
  Bullet.rails_logger = true
end
```

It catches:
- N+1 (suggest `includes`)
- Unused eager loading (you preloaded but didn't use it)
- Missing counter cache

## Test for N+1

```ruby
require "active_record/testing/query_assertions"

it "doesn't N+1 on the user association" do
  create_list(:post, 5)
  assert_no_n_plus_one_queries(model: Post) do
    get "/posts"
  end
end
```

Or with `rspec-rails`:

```ruby
expect { Post.includes(:user).each(&:user) }.to make_database_queries(count: 2)
```

## Common N+1 hotspots

- View loops: `<% @posts.each do |post| %><%= post.user.name %><% end %>`
- Serializers: every `attribute` that calls a method which queries
- Scopes that join + lazy-iterate: `posts.where(...).each(&:tag_names)`
- ActiveModel `as_json` deep nesting

## When NOT to optimize

- Very small N (you control the upper bound, e.g. <5 records)
- One-shot scripts where the cost is bounded
- Eager-loading would itself be a Cartesian explosion (10 has_many at once)

For Cartesian-explosion cases, prefer multiple smaller queries (preload) over one huge JOIN (eager_load).
