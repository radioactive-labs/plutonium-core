# 6. Adding Custom Actions

Our application now handles the basics of creating, reading, updating, and deleting posts and comments. But what about business logic that isn't simple CRUD? For this, Plutonium has **Actions**.

An Action is a piece of business logic you can execute on a resource. We'll create a "Publish" action for our posts.

Create a new file for our "interaction" at:
`packages/blogging/app/interactions/blogging/post_interactions/publish.rb`

## Implement the Interaction

The "Interaction" is where the business logic for an action lives. Open the newly created file and let's implement the logic to publish a post.

We want the action to set the `published_at` timestamp on the post.

```ruby
# packages/blogging/app/interactions/blogging/post_interactions/publish.rb
module Blogging
  module PostInteractions
    class Publish < Plutonium::Resource::Interaction
      # Define the attributes this interaction accepts
      attribute :resource, class: "Blogging::Post"

      # Define how this action is presented in the UI
      presents label: "Publish Post",
               description: "Make this post available for the public to see."

      private

      # The core business logic
      def execute
        if resource.update(published_at: Time.current )
          succeed(resource)
            .with_message("Post was successfully published.")
            .with_redirect_response(resource)
        else
          failed(resource.errors)
        end
      end
    end
  end
end
```

This class defines what the action needs (`resource`, `published_at`), how it looks (`presents`), and what it does (`execute`).

## Configure the Action

Now that we've defined the logic, we need to add the action to our `Post` resource and configure its visibility. We'll do this in the post's **definition** file.

`packages/blogging/app/definitions/blogging/post_definition.rb`

Add the `action` configuration:

```ruby
# packages/blogging/app/definitions/blogging/post_definition.rb
class Blogging::PostDefinition < Blogging::ResourceDefinition
  # ... (display helpers from the previous chapter)

  action :publish,
    interaction: "Blogging::PostInteractions::Publish"
end
```

## Control Visibility with a Policy

Plutonium actions are secure by default. If an action doesn't have a corresponding policy method allowing it, it won't be displayed.

Let's define the logic for our `publish` action. We only want to show the "Publish" button if the post hasn't been published yet.

Open the post policy file:
`packages/blogging/app/policies/blogging/post_policy.rb`

Add the `publish?` method:

```ruby
# packages/blogging/app/policies/blogging/post_policy.rb
class Blogging::PostPolicy < Blogging::ResourcePolicy
  # ... (other methods from previous chapters)

  def publish?
    # Only allow publishing if the user can update the post
    # and the post has not been published yet.
    update? && record.published_at.nil?
  end
end
```

This policy does two things:
1. It ensures the user has permission to `update?` the post.
2. It checks that `published_at` is `nil`.

Now, go to the show page for a post you created. You should see the "Publish" button. Click it, and the `published_at` field will be set. Because `record.published_at.nil?` is now false, the policy will prevent the action from being shown again. The button disappears!

![Plutonium Posts Publish Action](/tutorial/plutonium-publish-post.png)

## Next Steps

We've successfully added custom business logic to our application. Actions are a powerful way to build complex, maintainable features.

In the final chapter of this tutorial, we'll tighten up security by implementing proper authorization rules.
