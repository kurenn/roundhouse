# CSRF and XSS reference

Lazy-loaded by `rails-security` when a finding needs depth.

## XSS — Cross-site scripting

### Default escaping

ERB escapes everything by default:

```erb
<%= user.bio %>  <%# safe — escaped %>
<%== user.bio %> <%# UNSAFE — not escaped %>
<%= raw user.bio %>          <%# UNSAFE %>
<%= user.bio.html_safe %>    <%# UNSAFE — marks string as already safe %>
```

`raw` and `html_safe` mean "trust me, this is safe HTML." Both are footguns. Use only with output that is:
1. A literal string from your code (not user input)
2. A Rails helper return (which is already `html_safe`)
3. Output of `sanitize` with an explicit allowlist

### sanitize for user-generated HTML

```erb
<%= sanitize @post.body, tags: %w[p br strong em a ul ol li blockquote h2 h3], attributes: %w[href title] %>
```

Restrict the tags and attributes to the minimum your product needs. Avoid `<script>`, `<iframe>`, `<style>`, `on*` attributes, `javascript:` href.

### content_tag and link_to are safe

```erb
<%= content_tag :div, user.bio %>  <%# escapes user.bio %>
<%= link_to user.name, user_path(user) %>  <%# escapes user.name %>
```

The arguments are escaped before output. No html_safe needed.

### URL params in href / src

```erb
<%# UNSAFE — javascript:alert(1) is a valid URL %>
<a href="<%= params[:return_to] %>">Back</a>

<%# SAFE %>
<%= link_to "Back", url_for(params[:return_to]) if params[:return_to].start_with?("/") %>
```

Always allowlist the URL. Reject anything not starting with `/` or your domain.

### Content Security Policy

```ruby
# config/initializers/content_security_policy.rb
Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.script_src  :self, :https
  policy.style_src   :self, :https
  policy.img_src     :self, :data, :https
  policy.frame_src   :none
  policy.object_src  :none
  policy.report_uri "/csp_violation_reports"
end

Rails.application.config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
Rails.application.config.content_security_policy_nonce_directives = %w[script-src style-src]
```

CSP is defense-in-depth. Even if XSS exists, the browser refuses to execute foreign scripts.

Avoid `unsafe-inline` and `unsafe-eval`. Use nonces for inline scripts:

```erb
<%= javascript_tag nonce: true do %>
  console.log("hello");
<% end %>
```

## CSRF — Cross-site request forgery

Rails has CSRF protection on by default for non-API controllers:

```ruby
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception  # or :null_session for APIs
end
```

`form_with`, `form_for`, `button_to`, etc. include the CSRF token automatically.

### When CSRF tokens are missing

- AJAX requests need to include `X-CSRF-Token` header. The Rails `csrf_meta_tags` helper (in `application.html.erb` by default) makes this available; the Rails-UJS / Stimulus / Turbo defaults grab it automatically.
- API controllers (token-authenticated, no cookie session) → use `protect_from_forgery with: :null_session` or skip entirely:

```ruby
class Api::V1::BaseController < ActionController::API
  # ActionController::API skips CSRF by default — APIs use token auth
end
```

### Anti-pattern: blanket skip

```ruby
# DANGEROUS in a session-authenticated controller
skip_before_action :verify_authenticity_token
```

Only skip on actions that are explicitly designed for cross-origin POSTs (webhooks, OAuth callbacks). And those need their own auth (HMAC signature, shared secret, OAuth state).

### SameSite cookie attribute

```ruby
# config/initializers/session_store.rb
Rails.application.config.session_store :cookie_store,
  key: "_app_session",
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax  # or :strict if you don't have cross-site form posts
```

`same_site: :lax` blocks most CSRF attacks even without tokens. `:strict` blocks even more but breaks federated sign-in flows.

## Output encoding cheat sheet

| Context | Risk | Helper |
|---|---|---|
| HTML body | XSS | `<%= value %>` (default escape) |
| HTML attribute | attribute injection | `<%= value %>` (default escape) — but never `<a href="<%= unescaped %>">` |
| JavaScript string | code injection | `<%= value.to_json.html_safe %>` or `<%= json_escape(value) %>` |
| URL component | javascript: protocol | `url_for` with allowlisted scheme; reject non-HTTP |
| CSS value | CSS injection | `<%= value %>` is escaped, but never put user input into `style="..."` |

## Verify in code review

- Grep changed files for `raw(`, `html_safe`, `<%==`
- Grep for `redirect_to params[`
- Grep for `link_to ..., params[`
- Confirm CSP is configured (`config/initializers/content_security_policy.rb` exists and isn't all-default)
- Confirm `csrf_meta_tags` is in `application.html.erb`
