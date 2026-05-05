# SQL injection reference

Lazy-loaded by `rails-security` when an SQLi finding needs depth.

## The single rule

**Never interpolate user input into a query string.** Use parameter placeholders or hash conditions exclusively.

## Safe patterns

```ruby
# Hash conditions — automatically parameterized
User.where(role: params[:role])
User.where(role: params[:role], active: true)

# Parameter placeholders
User.where("name LIKE ?", "%#{params[:q]}%")
User.where("created_at > :since", since: 1.day.ago)

# Array conditions — also parameterized
User.where(id: [1, 2, 3])
User.where("name IN (?)", names)

# find_by, find_or_create_by — safe
User.find_by(email: params[:email])
```

## Dangerous patterns

```ruby
# String interpolation — ALL of these are SQLi
User.where("name = '#{params[:name]}'")
User.where("name = '" + params[:name] + "'")
User.where("created_at > #{params[:since]}")

# raw() and find_by_sql with interpolation
User.find_by_sql("SELECT * FROM users WHERE name = '#{params[:name]}'")

# pluck / select / group / order with interpolation
User.order(params[:sort_by])  # attacker can inject SQL via sort param
User.group(params[:group_field])
User.pluck(params[:column])  # attacker selects sensitive columns
User.select(params[:fields])
```

## Rails query methods that take SQL strings

Any method that accepts a SQL fragment as a string is an interpolation vector:

| Method | Risk | Safe form |
|---|---|---|
| `where(sql_string)` | high | `where(hash)` or `where("...?", value)` |
| `order(sql_string)` | high | `order(field: :asc)` or allowlist |
| `group(sql_string)` | high | `group(:column)` or allowlist |
| `having(sql_string)` | high | `having("count > ?", n)` |
| `joins(sql_string)` | high | `joins(:association)` or `joins("...")` with no input |
| `select(sql_string)` | high | `select(:column1, :column2)` or allowlist |
| `pluck(sql_string)` | high | `pluck(:column)` or allowlist |
| `find_by_sql(sql_string)` | high | parameterized array form: `find_by_sql(["...?", value])` |

## Allowlist pattern for dynamic ORDER / SELECT

```ruby
ALLOWED_SORT_COLUMNS = %w[name email created_at].freeze
ALLOWED_SORT_DIRECTIONS = %w[asc desc].freeze

def sort_users
  column = ALLOWED_SORT_COLUMNS.include?(params[:sort_by]) ? params[:sort_by] : "created_at"
  direction = ALLOWED_SORT_DIRECTIONS.include?(params[:direction]) ? params[:direction] : "desc"
  User.order("#{column} #{direction}")  # safe because column and direction are from allowlist
end
```

Allowlist is more readable AND safer than trying to escape arbitrary input.

## LIKE patterns and escaping

```ruby
# Even with placeholder, LIKE wildcards in user input may be a feature or a footgun
User.where("name LIKE ?", "%#{params[:q]}%")

# If user-controlled wildcards are not desired
User.where("name LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%")
```

`sanitize_sql_like` escapes `%` and `_` so they're treated literally.

## ActiveRecord arel — the safe DSL

For complex queries, prefer Arel (or scopes) over SQL strings:

```ruby
class User < ApplicationRecord
  scope :search, ->(query) {
    where(arel_table[:name].matches("%#{ActiveRecord::Base.sanitize_sql_like(query)}%"))
  }
end
```

## sanitize_sql for raw SQL

When you genuinely need raw SQL, use `sanitize_sql` to parameterize:

```ruby
sql = ActiveRecord::Base.sanitize_sql(["SELECT COUNT(*) FROM users WHERE created_at > ?", since])
ActiveRecord::Base.connection.execute(sql)
```

But for almost every case, ActiveRecord query methods cover it without raw SQL.

## Verifying a code review

Grep for these patterns in changed files:

```
grep -nE "where\(\".*#\{.*\}" app/   # interpolation in where
grep -nE "order\(params" app/        # user input in order
grep -nE "find_by_sql" app/          # raw sql with no array form
grep -nE "execute\(\".*#\{" app/     # interpolation in raw execute
```

Any match is a finding. Verify each.
