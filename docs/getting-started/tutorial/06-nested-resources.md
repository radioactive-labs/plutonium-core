# Chapter 6: Nested Resources

In this chapter, you'll add Comments as a nested resource under Posts.

## What are Nested Resources?

Nested resources are resources that belong to a parent resource. In our blog:
- Comments belong to Posts
- The URL reflects this: `/admin/blogging/posts/1/blogging/comments`
- Comments are automatically scoped to their parent post

## Generating the Comment Resource

```bash
rails generate pu:res:scaffold Comment body:text user:belongs_to Blogging/Post:belongs_to --dest=blogging
```

## Setting Up the Association

Update the Post model to add the `has_many` association:

```ruby
# packages/blogging/app/models/blogging/post.rb
class Blogging::Post < Blogging::ResourceRecord
  belongs_to :user
  has_many :comments, foreign_key: :post_id, dependent: :destroy
  # ... existing code
end
```

## The Comment Model

The generator creates:

```ruby
# packages/blogging/app/models/blogging/comment.rb
class Blogging::Comment < Blogging::ResourceRecord
  belongs_to :user
  belongs_to :post, class_name: "Blogging::Post"
  # ... generated code
end
```

Note: When referencing resources within the same package, the generator uses the short name (`:post`) while setting the appropriate `class_name` and foreign key to the correct table.

## Connecting to the Portal

Connect comments to the admin portal:

```bash
rails generate pu:res:conn Blogging::Comment --dest=admin_portal
```

Because `Comment` has `belongs_to :post`, Plutonium automatically creates nested routes:
- `GET /admin/blogging/posts/:blogging_post_id/blogging/comments`
- `POST /admin/blogging/posts/:blogging_post_id/blogging/comments`
- `GET /admin/blogging/posts/:blogging_post_id/blogging/comments/:id`

## Showing Comments on Post Detail

To show a comments panel on the post detail page, add `comments` to `permitted_associations` in the policy:

```ruby
# packages/blogging/app/policies/blogging/post_policy.rb
class Blogging::PostPolicy < Blogging::ResourcePolicy
  def permitted_associations
    %i[user comments]
  end
end
```

The panel links to the nested comments route and shows "Add Comment" if the user has permission.

## Comment Policy

Add authorization for comments:

```ruby
# packages/blogging/app/policies/blogging/comment_policy.rb
class Blogging::CommentPolicy < Blogging::ResourcePolicy
  def read?
    true # Anyone can read comments
  end

  def create?
    true # Anyone authenticated can comment
  end

  def update?
    owner?
  end

  def destroy?
    owner? || post_owner?
  end

  # Scope to comments on published posts (or user's own posts)
  def relation_scope(relation)
    relation.joins(:post).where(
      blogging_posts: {published: true}
    ).or(
      relation.where(user_id: user.id)
    )
  end

  private

  def owner?
    record.user_id == user.id
  end

  def post_owner?
    record.post.user_id == user.id
  end
end
```

## Nested Forms

You can edit comments directly on the post form using nested attributes:

```ruby
# In Post model
accepts_nested_attributes_for :comments, allow_destroy: true
```

```ruby
# In PostDefinition - option 1: inline block
nested_input :comments do |definition|
  definition.input :body
end

# In PostDefinition - option 2: use existing definition
nested_input :comments, using: Blogging::CommentDefinition, fields: %i[body]
```

This adds an inline comments editor to the post form.

## Nesting Limitations

Plutonium supports one level of nesting. For deeper hierarchies (e.g., Replies to Comments), keep URLs flat: `/blogging/comments/:blogging_comment_id/blogging/replies`

## What's Next

Our blog has posts and comments. In the next chapter, we'll create an Author Portal to show how multiple portals can share resources with different access levels.

[Continue to Chapter 7: Creating an Author Portal →](./07-author-portal)
