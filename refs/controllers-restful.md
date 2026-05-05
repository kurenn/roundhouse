# RESTful controllers reference

Lazy-loaded by `rails-controllers` for depth beyond the agent's non-negotiables.

## Stick to the seven actions

`index, show, new, create, edit, update, destroy` solve the vast majority of cases. Before adding a custom action, ask: "Can I model this as a new resource?"

```ruby
# BAD
class UsersController < ApplicationController
  def activate; ...; end
  def deactivate; ...; end
end

# GOOD
class User::ActivationsController < ApplicationController
  def create;  ...; end  # activate
  def destroy; ...; end  # deactivate
end
```

## Routing rules

- Use `resources` / `resource`. Avoid `match`/`get`/`post` for CRUD.
- Nest at most one level. Use `shallow:` for deeper.
- Use `namespace` for code-organized sections (admin, api), `scope` for URL-only grouping.
- Use `constraints` for domain/subdomain routing.

```ruby
resources :projects do
  resources :tasks, shallow: true
end
# /projects/:project_id/tasks (index, new, create)
# /tasks/:id (show, edit, update, destroy)

namespace :api do
  namespace :v1 do
    resources :users, only: [:index, :show, :create]
  end
end

resource :profile, only: [:show, :edit, :update]  # singular, no :id
```

## Strong parameters

Prefer `params.expect` (Rails 8+):

```ruby
def user_params
  params.expect(user: [:name, :email, :role])
end

# Nested attributes — double brackets for collections
def order_params
  params.expect(order: [
    :customer_name, :shipping_address,
    line_items_attributes: [[:product_id, :quantity, :id, :_destroy]]
  ])
end

# Arrays
def tag_params
  params.expect(post: [:title, :body, tag_ids: []])
end
```

Fallback for older Rails:

```ruby
def user_params
  params.require(:user).permit(:name, :email, :role,
    addresses_attributes: [:id, :street, :city, :_destroy])
end
```

Rules:
- One `*_params` private method per resource. Never inline `params.permit` in actions.
- Never `params.permit!`.
- Be explicit about array params: `tag_ids: []`.
- Be explicit about hash params: `metadata: {}`.

## Before/after/around actions

Use for: authentication, authorization, loading resources.
Don't use for: complex setup that only one action needs (put it in the action), more than 3-4 chained, anything that hides control flow, business logic.

```ruby
class PostsController < ApplicationController
  before_action :set_post, only: [:show, :edit, :update, :destroy]
  before_action :authorize_post, only: [:edit, :update, :destroy]

  private

  def set_post
    @post = Post.find(params[:id])  # one query, no side effects
  end

  def authorize_post
    redirect_to posts_path, alert: "Not authorized" unless @post.user == Current.user
  end
end
```

## Turbo responses

```ruby
class CommentsController < ApplicationController
  def create
    @comment = @post.comments.build(comment_params)

    if @comment.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @post, notice: "Comment added.", status: :see_other }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @comment = Comment.find(params[:id])
    @comment.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@comment) }
      format.html { redirect_to @comment.post, notice: "Comment removed.", status: :see_other }
    end
  end
end
```

Status codes:
- Validation failure → `422 :unprocessable_entity` (Turbo requires non-success non-redirect to re-render forms)
- Redirect after non-GET → `303 :see_other` (Turbo handles this correctly for non-GET redirects)

## Rate limiting (Rails 8+)

```ruby
class SessionsController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :create
  # by IP by default; customize with `by:`
  rate_limit to: 5, within: 1.minute, only: :create,
    by: -> { params.dig(:session, :email_address) || request.ip }
end

class Api::V1::BaseController < ActionController::API
  rate_limit to: 100, within: 1.minute
end
```

Limit exceeded raises `ActionController::TooManyRequests` and returns 429.

## Authentication patterns (Rails 8 generated)

```ruby
class ApplicationController < ActionController::Base
  include Authentication
end

# allow_unauthenticated_access for public actions:
class HomeController < ApplicationController
  allow_unauthenticated_access only: :index
end
```

Use `Current.user` over `current_user` if the project follows Rails 8 conventions. `Current` is thread-local, set per-request, cleared after.

## Anti-patterns

- More than 7 public actions in one controller → split
- `redirect_back` without `fallback_location:` → raises if no referer
- `redirect_to` after `render` → already-rendered error
- Rendering inside a `before_action` and continuing → use `performed?` guard
- Exposing internal errors to users in production → rescue at the application level
- One controller handling two resources → split
