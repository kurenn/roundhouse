# Tailwind in Rails reference

Lazy-loaded by `rails-tailwind` for depth on integration patterns.

## tailwindcss-rails gem

The `tailwindcss-rails` gem is the standard. It bundles a standalone Tailwind CLI (no Node required) and wires it into the Rails dev workflow.

Key files:
- `tailwind.config.js` — theme + plugin config
- `app/assets/stylesheets/application.tailwind.css` — entry point with `@tailwind` directives
- `app/assets/builds/application.css` — compiled output (gitignored typically)

Commands:
- `bin/rails tailwindcss:install` — initial setup (run once per app)
- `bin/rails tailwindcss:build` — one-shot compile
- `bin/rails tailwindcss:watch` — watch mode (used by `bin/dev` via `Procfile.dev`)

Always run `bin/dev` for development, not `bin/rails server`. The Procfile starts the server AND the tailwind watcher.

## Content paths in tailwind.config.js

Tailwind only includes utilities it finds in your source. Paths must cover everywhere you use classes:

```javascript
// tailwind.config.js
module.exports = {
  content: [
    "./public/*.html",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js",
    "./app/views/**/*.{erb,haml,html,slim}",
    "./app/components/**/*.{rb,html.erb}",
    "./app/mailers/**/*.rb",
    "./app/views/**/*.{erb,html,slim}"
  ],
  theme: { extend: {} },
  plugins: []
}
```

ViewComponent users: include both `*.rb` and `*.html.erb` under `app/components/` because component classes can hold class strings as constants.

## The dynamic class pitfall

Tailwind's compiler scans source files for class names AS STRING LITERALS. Anything dynamically constructed will be purged.

```erb
<%# BAD: bg-#{color}-500 is never a literal substring in the source %>
<div class="bg-<%= color %>-500">...</div>

<%# GOOD: full classnames present as strings %>
<% color_classes = { primary: "bg-blue-500", danger: "bg-red-500" } %>
<div class="<%= color_classes[color] %>">...</div>
```

If dynamic classes are unavoidable, allowlist them in `tailwind.config.js`:

```javascript
module.exports = {
  content: [...],
  safelist: [
    "bg-red-500", "bg-blue-500", "bg-green-500",
    {
      pattern: /bg-(red|green|blue)-(100|500|900)/,
    }
  ]
}
```

## Common Rails-specific patterns

### Form validation styles

```erb
<%= form_with(model: @post) do |f| %>
  <div>
    <%= f.label :title %>
    <%= f.text_field :title, class: "block w-full rounded-md #{@post.errors[:title].any? ? 'border-red-500' : 'border-gray-300'}" %>
    <% @post.errors[:title].each do |msg| %>
      <p class="text-sm text-red-600"><%= msg %></p>
    <% end %>
  </div>
<% end %>
```

### Flash messages

```erb
<%# app/views/shared/_flash.html.erb %>
<% flash.each do |type, message| %>
  <div class="<%= flash_classes(type) %>" role="alert"><%= message %></div>
<% end %>
```

```ruby
# app/helpers/application_helper.rb
def flash_classes(type)
  base = "rounded-md p-4 mb-4"
  case type.to_sym
  when :notice  then "#{base} bg-green-50 text-green-800 border border-green-200"
  when :alert, :error then "#{base} bg-red-50 text-red-800 border border-red-200"
  else "#{base} bg-gray-50 text-gray-800 border border-gray-200"
  end
end
```

The whole class strings appear in source → tailwind picks them up.

### Buttons via partials

```erb
<%# app/views/shared/_button.html.erb %>
<%# locals: (text:, url: nil, variant: :primary, **html_options) %>

<% classes = [
  "inline-flex items-center px-4 py-2 rounded-md font-medium focus:outline-none focus:ring-2 focus:ring-offset-2",
  case variant
  when :primary    then "bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500"
  when :secondary  then "bg-white text-gray-900 border border-gray-300 hover:bg-gray-50 focus:ring-blue-500"
  when :danger     then "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500"
  end,
  html_options.delete(:class)
].compact.join(" ") %>

<% if url %>
  <%= link_to text, url, class: classes, **html_options %>
<% else %>
  <%= button_tag text, class: classes, **html_options %>
<% end %>
```

```erb
<%= render "shared/button", text: "Sign up", url: new_user_path, variant: :primary %>
```

## Dark mode

```javascript
// tailwind.config.js
module.exports = {
  darkMode: "class",  // or "media" for OS-level
  ...
}
```

```erb
<div class="bg-white text-gray-900 dark:bg-gray-900 dark:text-white">
```

Toggle: a Stimulus controller adds/removes the `dark` class on `<html>`.

## Hotwire-aware styling

Turbo replaces frame and stream content. CSS transitions on appearance work natively. For exit animations (an element being removed), use `[data-turbo-temporary]` or handle via a Stimulus controller's `disconnect` callback.

## Anti-patterns

- Custom CSS in `application.css` for things tailwind already provides (margin, padding, color)
- Reaching for `@apply` to compose utilities — usually a sign you should extract a partial or component
- Massive class strings copied across many templates without extraction
- Disabling tailwind's purge to "make all classes available" — bloats the bundle, never required
