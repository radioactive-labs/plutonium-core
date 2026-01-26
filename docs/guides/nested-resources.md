# Nested Resources

This guide covers setting up parent/child resource relationships.

## Overview

Nested resources create URLs like `/posts/1/nested_comments` where comments belong to a specific post. Plutonium automatically handles:

- Scoping queries to the parent
- Assigning parent to new records
- Hiding parent field in forms
- URL generation with parent context
- Breadcrumb navigation

Plutonium supports both `has_many` (plural routes) and `has_one` (singular routes) associations.

## Setting Up Nested Resources

### 1. Define the Association

```ruby
# Parent model
class Post < ResourceRecord
  has_many :comments, dependent: :destroy
  has_one :post_metadata, dependent: :destroy
end

# Child models
class Comment < ResourceRecord
  belongs_to :post
end

class PostMetadata < ResourceRecord
  belongs_to :post
end
```

### 2. Register Both Resources

```ruby
# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  register_resource ::Post
  register_resource ::Comment
  register_resource ::PostMetadata
end
```

Plutonium automatically creates nested routes with a `nested_` prefix based on the `belongs_to` association:

**has_many routes (plural):**
- `GET /posts/:post_id/nested_comments`
- `GET /posts/:post_id/nested_comments/new`
- `GET /posts/:post_id/nested_comments/:id`
- etc.

**has_one routes (singular):**
- `GET /posts/:post_id/nested_post_metadata`
- `GET /posts/:post_id/nested_post_metadata/new`
- `GET /posts/:post_id/nested_post_metadata/edit`

The `nested_` prefix prevents route conflicts when the same resource is registered both as a top-level and nested resource.

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
# Child collection (has_many)
resource_url_for(Comment, parent: @post)
# => /posts/123/nested_comments

# Child record
resource_url_for(@comment, parent: @post)
# => /posts/123/nested_comments/456

# New child form
resource_url_for(Comment, action: :new, parent: @post)
# => /posts/123/nested_comments/new

# Edit child
resource_url_for(@comment, action: :edit, parent: @post)
# => /posts/123/nested_comments/456/edit

# Singular resource (has_one)
resource_url_for(@post_metadata, parent: @post)
# => /posts/123/nested_post_metadata

resource_url_for(PostMetadata, action: :new, parent: @post)
# => /posts/123/nested_post_metadata/new
```

Within a nested context, `parent:` defaults to `current_parent`:

```ruby
# In CommentsController under /posts/:post_id/nested_comments
resource_url_for(@comment)  # parent: current_parent is automatic
```

### Cross-Package URL Generation

Generate URLs for resources in a different package:

```ruby
# From AdminPortal, generate URL to CustomerPortal resource
resource_url_for(@comment, parent: @post, package: CustomerPortal)
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

### Parent Scoping Context

For nested resources, policies receive `parent` and `parent_association` context. This is used for automatic query scoping:

```ruby
class CommentPolicy < ResourcePolicy
  # Available context:
  # - parent: the parent record (e.g., Post instance)
  # - parent_association: the association name (e.g., :comments)
  # - entity_scope: the scoped entity (for multi-tenancy)

  relation_scope do |relation|
    relation = super(relation)  # Applies parent scoping automatically
    relation
  end
end
```

**Parent scoping takes precedence over entity scoping** - when a parent is present, the policy scopes via the parent association rather than the entity scope. This prevents double-scoping since the parent was already authorized and entity-scoped.

### has_many vs has_one Scoping

For **has_many** associations, scoping uses the association directly:
```ruby
parent.send(parent_association)  # e.g., post.comments
```

For **has_one** associations, scoping uses a where clause:
```ruby
relation.where(foreign_key => parent.id)  # e.g., where(post_id: post.id)
```

### Entity Scope Fallback

When no parent is present (top-level resource access), entity_scope is used:

```ruby
class CommentPolicy < ResourcePolicy
  def create?
    # entity_scope is available for multi-tenancy
    entity_scope.present? && user.can_comment_on?(entity_scope)
  end
end
```

### Additional Scoping

Add role-based filtering on top of parent scoping:

```ruby
class CommentPolicy < ResourcePolicy
  relation_scope do |relation|
    relation = super(relation)  # Applies parent scoping first

    if user.moderator?
      relation
    else
      relation.where(approved: true).or(relation.where(user: user))
    end
  end
end
```

### default_relation_scope is Required

Plutonium verifies that `default_relation_scope` is called in every `relation_scope` to prevent multi-tenancy leaks:

```ruby
# ❌ This will raise an error
relation_scope do |relation|
  relation.where(approved: true)  # Missing default_relation_scope!
end

# ✅ Correct
relation_scope do |relation|
  default_relation_scope(relation).where(approved: true)
end
```

When overriding an inherited scope but still wanting parent scoping:

```ruby
class AdminCommentPolicy < CommentPolicy
  relation_scope do |relation|
    # Replace inherited scope but keep parent scoping
    default_relation_scope(relation)
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

## has_one Associations

Plutonium supports `has_one` associations with singular routes:

```ruby
class Post < ResourceRecord
  has_one :post_metadata, dependent: :destroy
end
```

Routes generated:
- `GET /posts/:post_id/nested_post_metadata` - Show metadata
- `GET /posts/:post_id/nested_post_metadata/new` - New metadata form
- `GET /posts/:post_id/nested_post_metadata/edit` - Edit metadata form
- `PATCH /posts/:post_id/nested_post_metadata` - Update metadata
- `DELETE /posts/:post_id/nested_post_metadata` - Delete metadata

Note: No `:id` parameter in singular routes - only one record can exist per parent.

## Nesting Depth

Plutonium supports **one level of nesting**:

- `/posts/:post_id/nested_comments` (parent → child)
- `/comments/:comment_id/nested_replies` (parent → child)

Not supported:
- `/posts/:post_id/nested_comments/:comment_id/nested_replies` (grandparent → parent → child)

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
    post :approve, as: :approve
    post :flag, as: :flag
  end
  collection do
    get :pending, as: :pending
  end
end
```

::: warning Always Name Custom Routes
Always use the `as:` option when defining custom routes. This ensures `resource_url_for` can generate correct URLs. Without named routes, URL generation will fail for nested resources.
:::

Generates nested routes:
- `POST /posts/:post_id/nested_comments/:id/approve`
- `POST /posts/:post_id/nested_comments/:id/flag`
- `GET /posts/:post_id/nested_comments/pending`

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
