# Nested Resources

This guide covers setting up parent/child resource relationships.

## Overview

Nested resources create URLs like `/posts/1/comments` where comments belong to a specific post. Plutonium automatically handles:

- Scoping queries to the parent
- Assigning parent to new records
- Hiding parent field in forms
- URL generation with parent context
- Breadcrumb navigation

## Setting Up Nested Resources

### 1. Define the Association

```ruby
# Parent model
class Post < ResourceRecord
  has_many :comments, dependent: :destroy
end

# Child model
class Comment < ResourceRecord
  belongs_to :post
end
```

### 2. Register Both Resources

```ruby
# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  register_resource ::Post
  register_resource ::Comment
end
```

Plutonium automatically creates nested routes based on the `belongs_to` association:
- `GET /posts/:post_id/comments`
- `GET /posts/:post_id/comments/new`
- `GET /posts/:post_id/comments/:id`
- etc.

### 3. Enable Association Panel

Show comments on the post detail page:

```ruby
class PostPolicy < ResourcePolicy
  def permitted_associations
    %i[comments]
  end
end
```

## How It Works

### Automatic Scoping

When accessing `/posts/1/comments`, queries are scoped to the parent:

```ruby
# Internally uses: Comment.associated_with(post)
# Which resolves to: Comment.where(post: post)
```

### Automatic Parent Assignment

When creating a comment under a post, the parent is injected into params:

```ruby
# POST /posts/1/comments
# resource_params automatically includes { post: <Post:1>, post_id: 1 }
```

### Automatic Field Hiding

The parent field (`post`) is automatically hidden in forms since it's determined by the URL.

## Controller Helpers

### current_parent

Returns the parent record resolved from the URL:

```ruby
# URL: /posts/123/comments
current_parent  # => Post.find(123)
```

### parent_route_param

The URL parameter containing the parent ID:

```ruby
parent_route_param  # => :post_id
```

### parent_input_param

The association name on the child model:

```ruby
parent_input_param  # => :post
```

## URL Generation

Use `resource_url_for` with the `parent:` option:

```ruby
# Child collection
resource_url_for(Comment, parent: @post)
# => /posts/123/comments

# Child record
resource_url_for(@comment, parent: @post)
# => /posts/123/comments/456

# New child form
resource_url_for(Comment, action: :new, parent: @post)
# => /posts/123/comments/new

# Edit child
resource_url_for(@comment, action: :edit, parent: @post)
# => /posts/123/comments/456/edit
```

Within a nested context, `parent:` defaults to `current_parent`:

```ruby
# In CommentsController under /posts/:post_id/comments
resource_url_for(@comment)  # parent: current_parent is automatic
```

## Presentation Hooks

Control whether the parent field appears:

```ruby
class CommentsController < ResourceController
  private

  # Show parent in displays (default: false when nested)
  def present_parent?
    current_parent.nil?  # Only show when accessed standalone
  end

  # Allow changing parent in forms (default: same as present_parent?)
  def submit_parent?
    false
  end
end
```

## Policy Integration

### Parent Authorization

The parent is authorized for `:read?` before being returned:

```ruby
# Inside current_parent
authorize! parent, to: :read?
```

### Entity Scope Context

The parent is passed to child policies as `entity_scope`:

```ruby
class CommentPolicy < ResourcePolicy
  def create?
    # entity_scope is the parent post
    entity_scope.present? && user.can_comment_on?(entity_scope)
  end

  def update?
    record.user_id == user.id
  end

  def destroy?
    record.user_id == user.id || entity_scope&.user_id == user.id
  end
end
```

### Additional Scoping

Add role-based filtering on top of parent scoping:

```ruby
class CommentPolicy < ResourcePolicy
  relation_scope do |relation|
    relation = super(relation)  # Applies associated_with(entity_scope)

    if user.moderator?
      relation
    else
      relation.where(approved: true).or(relation.where(user: user))
    end
  end
end
```

## Association Panels

Associations listed in `permitted_associations` appear on the parent's show page:

```ruby
class PostPolicy < ResourcePolicy
  def permitted_associations
    %i[comments tags]  # Shows panels for these
  end
end
```

Each panel displays:
- List of child records
- "Add" button linking to nested new action
- Edit/Delete actions per record

## Nested Forms

Edit child records inline within the parent form:

### 1. Enable Nested Attributes

```ruby
class Post < ResourceRecord
  has_many :comments

  accepts_nested_attributes_for :comments,
                                allow_destroy: true,
                                reject_if: :all_blank
end
```

### 2. Configure as Nested Input

```ruby
class PostDefinition < ResourceDefinition
  input :comments, as: :nested
end
```

### 3. Permit in Policy

```ruby
class PostPolicy < ResourcePolicy
  def permitted_attributes_for_create
    [:title, :content, comments_attributes: [:id, :body, :_destroy]]
  end
end
```

## Nesting Depth

Plutonium supports **one level of nesting**:

- `/posts/:post_id/comments` (parent → child)
- `/comments/:comment_id/replies` (parent → child)

Not supported:
- `/posts/:post_id/comments/:comment_id/replies` (grandparent → parent → child)

### Working with Deep Hierarchies

Use through associations for data access:

```ruby
class Post < ResourceRecord
  has_many :comments
  has_many :replies, through: :comments
end
```

## Custom Routes on Nested Resources

Add member/collection routes:

```ruby
register_resource ::Comment do
  member do
    post :approve
    post :flag
  end
  collection do
    get :pending
  end
end
```

Generates nested routes:
- `POST /posts/:post_id/comments/:id/approve`
- `POST /posts/:post_id/comments/:id/flag`
- `GET /posts/:post_id/comments/pending`

## Breadcrumbs

Nested resources automatically include parent in breadcrumbs:

```
Dashboard > Posts > My First Post > Comments > Comment #1
```

## Scoped Uniqueness

Validate uniqueness within parent:

```ruby
class Comment < ResourceRecord
  belongs_to :post
  validates :position, uniqueness: { scope: :post_id }
end
```

## Example: Blog with Comments

### Models

```ruby
class Post < ResourceRecord
  belongs_to :user
  has_many :comments, dependent: :destroy

  validates :title, :body, presence: true
end

class Comment < ResourceRecord
  belongs_to :post
  belongs_to :user

  validates :body, presence: true
end
```

### Policies

```ruby
class PostPolicy < ResourcePolicy
  def create?
    user.present?
  end

  def read?
    true
  end

  def permitted_attributes_for_create
    %i[title body]
  end

  def permitted_attributes_for_read
    %i[title body user created_at]
  end

  def permitted_associations
    %i[comments]
  end
end

class CommentPolicy < ResourcePolicy
  def create?
    user.present? && entity_scope.present?
  end

  def read?
    true
  end

  def update?
    record.user_id == user.id
  end

  def destroy?
    record.user_id == user.id || entity_scope&.user_id == user.id
  end

  def permitted_attributes_for_create
    %i[body]
  end

  def permitted_attributes_for_read
    %i[body user created_at]
  end
end
```

### Controller (if customization needed)

```ruby
class CommentsController < ResourceController
  private

  def build_resource
    super.tap do |comment|
      comment.user = current_user
    end
  end
end
```

## Related

- [Adding Resources](./adding-resources)
- [Authorization](./authorization)
- [Creating Packages](./creating-packages)
