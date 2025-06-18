# 7. Implementing Authorization

Our blog is now fully functional, but it's not very secure. Any user can edit or delete any other user's posts. Let's fix this by implementing proper authorization rules using Plutonium's **Policy** system.

## Understanding Policies

For every resource, there is a corresponding Policy class that controls access. The policy methods (like `update?` or `destroy?`) return `true` or `false` to grant or deny permission.

## Securing Post Actions

Let's start by restricting the `update` and `publish` actions for posts. Open the post policy file:

`packages/blogging/app/policies/blogging/post_policy.rb`

Now, let's modify the policy to check if the current user (`user`) is the owner of the post (`record`).

```ruby
# packages/blogging/app/policies/blogging/post_policy.rb
class Blogging::PostPolicy < Blogging::ResourcePolicy
  # Users can only update their own posts
  def update?
    record.user_id == user.id
  end

  # Only the owner can publish their post
  def publish?
    update? # Inherits from update?
  end
end
```
By default, `destroy?` also inherits from `update?`, so this one change secures all write operations.

## Securing Comment Actions

We should apply the same logic to comments. Open the comment policy:

`packages/blogging/app/policies/blogging/comment_policy.rb`

And add the same ownership check:

```ruby
# packages/blogging/app/policies/blogging/comment_policy.rb
class Blogging::CommentPolicy < Blogging::ResourcePolicy
  def update?
    record.user_id == user.id
  end
end
```

## Scoping Visible Data

We've secured the actions, but there's one more problem: every user can see every post in the index view. We should scope the list of posts so that users only see their own.

This is done with the `relation_scope` in the post policy file. This scope is applied to all queries for the `Post` resource.

`packages/blogging/app/policies/blogging/post_policy.rb`

```ruby
# packages/blogging/app/policies/blogging/post_policy.rb
class Blogging::PostPolicy < Blogging::ResourcePolicy
  # ... (update? and publish? methods)

  # Scope all queries to only include the current user's posts
  relation_scope do |scope|
    scope.where(user: user)
  end
end
```
Now, the posts index page will only show posts created by the currently logged-in user. This is a critical feature for multi-tenant applications.

## Tutorial Complete!

Congratulations! You have built a complete, secure, and modular blog application with Plutonium.

You've learned how to:
- Set up a Plutonium project.
- Organize features into **Packages**.
- Define and scaffold **Resources**.
- Build a web interface with **Portals**.
- Customize the UI.
- Add custom business logic with **Actions**.
- Secure your application with **Policies**.

### Where to Go Next?

You now have a strong foundation to build your own applications. To learn more about specific topics, check out our **Deep Dive Guides**:

- **[Resources](./../deep-dive/resources.md)**: An in-depth look at fields, associations, filters, and more.
- **[Authorization](./../deep-dive/authorization.md)**: A detailed guide to policies, scopes, and entity-based authorization.
- ... more guides coming soon!
