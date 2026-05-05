# Turbo (Hotwire) reference

Lazy-loaded by `rails-views` and `rails-controllers` when working on Hotwire-based UI.

## Turbo Frames

A frame scopes the response to itself. Click a link inside a `<turbo-frame id="comments">`, and Turbo replaces only that frame's content with the matching frame from the response.

```erb
<%# show.html.erb %>
<%= turbo_frame_tag "comments" do %>
  <%= render @post.comments %>
  <%= link_to "Add a comment", new_post_comment_path(@post) %>
<% end %>
```

```erb
<%# new.html.erb (the form) %>
<%= turbo_frame_tag "comments" do %>
  <%= form_with(model: [@post, @comment]) do |f| %>
    ...
  <% end %>
<% end %>
```

The controller doesn't need special handling. Render the same template — Turbo extracts the matching frame.

To check if the current request is a frame request:

```ruby
def index
  @posts = Post.all
  if turbo_frame_request?
    render partial: "posts/list", locals: { posts: @posts }
  end
end
```

## Turbo Streams

Used to update multiple regions of the page from one action. Stream actions: `append`, `prepend`, `replace`, `update`, `remove`, `before`, `after`.

### From the controller

```ruby
class CommentsController < ApplicationController
  def create
    @comment = @post.comments.build(comment_params)

    if @comment.save
      respond_to do |format|
        format.turbo_stream  # renders create.turbo_stream.erb
        format.html { redirect_to @post, status: :see_other }
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
      format.html { redirect_to @comment.post, status: :see_other }
    end
  end
end
```

### create.turbo_stream.erb

```erb
<%= turbo_stream.append "comments", @comment %>
<%= turbo_stream.replace "new_comment", partial: "comments/form", locals: { comment: Comment.new } %>
<%= turbo_stream.update "flash", partial: "shared/flash" %>
```

`@comment` as a second argument renders `comments/_comment.html.erb` partial automatically (Rails name resolution).

### Multiple actions in one stream

Use `turbo_stream` helper chained or as multiple statements:

```erb
<%= turbo_stream.replace @comment %>
<%= turbo_stream.update "comment_count", @post.comments.size %>
```

## Broadcasting (real-time updates)

```ruby
class Comment < ApplicationRecord
  belongs_to :post
  broadcasts_to :post  # broadcasts to "post_<id>_comments"
end
```

```erb
<%# show.html.erb %>
<%= turbo_stream_from @post %>
<%= turbo_frame_tag "comments" do %>
  <%= render @post.comments %>
<% end %>
```

When a comment is created/updated/destroyed, all clients viewing this post see the change without polling.

## Status codes (matter for Turbo)

| Action | Code | Why |
|---|---|---|
| Validation failure on create/update | 422 `:unprocessable_entity` | Turbo re-renders the form with errors. 200 would silently navigate away. |
| Redirect after destroy/update/create | 303 `:see_other` | Required for Turbo to follow the redirect on non-GET. |

## Anti-patterns

- Returning HTML on a Turbo Stream request → use `turbo_stream:` template
- Forgetting `status: :unprocessable_entity` on validation failure → form silently navigates away
- Forgetting `status: :see_other` on redirect after non-GET → Turbo refuses to follow
- Heavy logic in `*.turbo_stream.erb` → extract to a presenter or service
- More than 5 stream actions in one response → page is doing too much; split into separate updates
