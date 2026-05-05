# Strong parameters reference

Lazy-loaded by `rails-controllers` when the parameter shape is non-trivial.

## Rails 8: params.expect

Stricter than `require(...).permit(...)`. Validates structure, not just presence. Raises on mismatch instead of silently dropping data.

```ruby
def user_params
  params.expect(user: [:name, :email, :role])
end
```

## Nested attributes

Use double brackets for collections of nested attributes:

```ruby
def order_params
  params.expect(order: [
    :customer_name,
    :shipping_address,
    line_items_attributes: [[:product_id, :quantity, :id, :_destroy]]
  ])
end
```

The single brackets `line_items_attributes: [...]` would expect ONE line item. Double `[[...]]` expects an array.

## Array params

```ruby
# Permits an array of strings
params.expect(post: [:title, :body, tag_ids: []])

# Permits an array of hashes (use double brackets)
params.expect(post: [:title, attachments: [[:url, :alt]]])
```

## Hash with dynamic keys (jsonb fields, settings)

```ruby
# Permit any keys under metadata
params.require(:setting).permit(preferences: {})

# But filter inside the controller — don't blindly accept user-controlled hashes for security-sensitive fields
def setting_params
  permitted = params.require(:setting).permit(preferences: {})
  permitted[:preferences] = permitted[:preferences].slice(:theme, :timezone, :language)
  permitted
end
```

## File uploads

```ruby
def avatar_params
  params.expect(user: [:avatar])  # single ActiveStorage attachment
end

def attachments_params
  params.expect(post: [attachments: []])  # multiple
end
```

ActiveStorage attachments are permitted as scalars. Validate content_type and size on the model:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
  validate :acceptable_avatar

  private

  def acceptable_avatar
    return unless avatar.attached?
    errors.add(:avatar, "must be an image") unless avatar.content_type.in?(%w[image/jpeg image/png image/webp])
    errors.add(:avatar, "must be < 5MB") if avatar.byte_size > 5.megabytes
  end
end
```

## When permission is conditional

Different fields permitted based on user role:

```ruby
def user_params
  permitted = [:name, :email]
  permitted += [:role, :admin] if Current.user.admin?
  params.expect(user: permitted)
end
```

Don't try to do this in routes or before_actions — keep it in the params method, where it's local to the controller and easy to read.

## Anti-patterns

- `params.permit!` — disables strong parameters entirely. Never.
- `params[:user]` directly into `User.new` or `update` — bypasses strong params.
- Permitting fields you don't expect to receive — when in doubt, omit. Easier to add later than to discover a security hole.
- Permitting a `:type` column on an STI model — lets attackers change the type and gain new behavior.
- Permitting an `:admin` boolean from form params — should be set internally, never from user input.
