# ViewComponent reference

Lazy-loaded by `rails-views` only when the project uses ViewComponent (`gem "view_component"`).

ViewComponents live in `app/components/`. Each component is a Ruby class + an ERB template.

## Anatomy

```ruby
# app/components/button_component.rb
class ButtonComponent < ViewComponent::Base
  def initialize(text:, url: nil, variant: :primary, **html_options)
    @text = text
    @url = url
    @variant = variant
    @html_options = html_options
  end

  private

  attr_reader :text, :url, :variant, :html_options

  def base_classes
    "inline-flex items-center px-4 py-2 rounded-md font-medium"
  end

  def variant_classes
    {
      primary: "bg-blue-600 text-white hover:bg-blue-700",
      secondary: "bg-white text-gray-900 border border-gray-300 hover:bg-gray-50",
      danger: "bg-red-600 text-white hover:bg-red-700"
    }.fetch(variant, variant_classes[:primary])
  end

  def classes
    "#{base_classes} #{variant_classes} #{html_options.delete(:class)}"
  end
end
```

```erb
<%# app/components/button_component.html.erb %>
<% if url %>
  <%= link_to text, url, class: classes, **html_options %>
<% else %>
  <%= button_tag text, class: classes, **html_options %>
<% end %>
```

```erb
<%# usage in any view %>
<%= render ButtonComponent.new(text: "Sign up", url: new_user_path, variant: :primary) %>
```

## Slots — for content composition

```ruby
class CardComponent < ViewComponent::Base
  renders_one :header
  renders_one :footer
  renders_many :actions
end
```

```erb
<%# template %>
<div class="card">
  <% if header? %>
    <div class="card-header"><%= header %></div>
  <% end %>

  <div class="card-body"><%= content %></div>

  <% if actions.any? %>
    <div class="card-actions">
      <% actions.each do |action| %>
        <%= action %>
      <% end %>
    </div>
  <% end %>
</div>
```

```erb
<%# usage %>
<%= render CardComponent.new do |card| %>
  <% card.with_header do %>
    <h2>Welcome</h2>
  <% end %>

  <p>Body content here</p>

  <% card.with_action do %>
    <%= render ButtonComponent.new(text: "Continue", variant: :primary) %>
  <% end %>
<% end %>
```

## Strict locals (preferred for partials, optional for components)

```ruby
class CardComponent < ViewComponent::Base
  def initialize(title:, variant: :default)
    @title = title
    @variant = variant
  end
end
```

The `initialize` signature IS the strict-locals contract. Required keyword args raise on missing input.

## Testing

```ruby
RSpec.describe ButtonComponent, type: :component do
  it "renders a link when url is provided" do
    render_inline(described_class.new(text: "Sign up", url: "/users/new"))
    expect(page).to have_link("Sign up", href: "/users/new")
  end

  it "renders a button when no url" do
    render_inline(described_class.new(text: "Submit"))
    expect(page).to have_button("Submit")
  end

  it "applies variant classes" do
    render_inline(described_class.new(text: "Delete", variant: :danger))
    expect(page).to have_css(".bg-red-600")
  end
end
```

## When to extract a ViewComponent vs. a partial

| Use a partial | Use a ViewComponent |
|---|---|
| Pure presentation, no logic | Logic in the helper feels awkward |
| Reused in 1-2 places | Reused in 3+ places |
| No state | Has slots, variants, multiple modes |
| Simple iteration | Tested in isolation |

Don't reach for ViewComponent on day one. A `<%# locals: %>` partial covers most cases.

## Anti-patterns

- Components that query the database (use a presenter, or pass the data in)
- Components with `before_render` that does I/O — slow and unpredictable
- Tightly-coupled component hierarchies (parent component's slot directly accesses child internals)
- Components that are 90% conditional rendering — split into multiple components
