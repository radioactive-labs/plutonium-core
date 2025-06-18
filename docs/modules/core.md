---
title: Core Module
---

# Core Module

The Core module provides the fundamental building blocks for Plutonium applications. It contains base controllers and essential framework components that all other modules build upon.

::: tip
The Core module is located in `lib/plutonium/core/`.
:::

## Overview

- **Base Controller**: Provides `Plutonium::Core::Controller` for all application controllers to inherit from.
- **Controller Concerns**: A set of mixins for common functionalities like authorization and multi-tenancy.
- **Integration Points**: Seamlessly integrates with other Plutonium modules like Resource, Auth, and Policy.

## Base Controller (`Plutonium::Core::Controller`)

The core controller that all Plutonium controllers should inherit from, typically by including it in your `ApplicationController`.

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Plutonium::Core::Controller

  # Your application-specific logic
end
```

It provides essential methods for URL generation, resource management, and error handling, acting as the glue for the framework.

::: details Key Methods
- `resource_url_for`: Generates URLs for resources with proper routing and namespacing.
- `resource_url_args_for`: Builds the underlying URL arguments for a resource.
- `registered_resources`: Provides access to all registered resources in the application.
- `current_policy`: Returns the policy object for the current resource being handled.
:::

## Controller Concerns

The Core module includes several concerns that provide specific functionality.

::: code-group
```ruby [Bootable]
# lib/plutonium/core/controllers/bootable.rb

# Handles controller initialization and setup.
# - Registers flash message types (:success, :warning, :error)
# - Configures ActiveStorage URL options
# - Manages view paths and layouts for Turbo Frame requests
```
```ruby [EntityScoping]
# lib/plutonium/core/controllers/entity_scoping.rb

# Provides multi-tenancy and entity scoping.
# - Automatically scopes resources to the current entity (e.g., tenant).
# - Manages entity resolution from URL params or subdomains.
# - Key methods: `scoped_to_entity?`, `current_scoped_entity`
```
```ruby [Authorizable]
# lib/plutonium/core/controllers/authorizable.rb

# Integrates with ActionPolicy for authorization.
# - Automatically applies policies to resources.
# - Provides helpers for checking permissions and scoping collections.
# - Key methods: `authorized_resource_scope`, `policy_for`, `authorize_current!`
```
:::

## Advanced Usage

### Custom Controller Actions

You can extend controllers with custom actions that still leverage Plutonium's authorization and resource management.

```ruby
class PostsController < ApplicationController
  # This action is defined in the resource definition.
  # The `interaction` class handles the business logic.
  def publish
    # `authorize_resource!` is automatically called.
    # It checks the `publish?` method on the PostPolicy.
    authorize_resource!

    outcome = PublishPostInteraction.call(id: params[:id])

    if outcome.success?
      redirect_to post_path(outcome.value), notice: "Post published."
    else
      redirect_back fallback_location: posts_path, alert: "Failed to publish."
    end
  end
end
```

## Best Practices

::: details Controller Organization
1.  **Keep controllers thin**: Move business logic into Interaction classes.
2.  **Leverage resource definitions**: Configure resource behavior declaratively instead of in the controller.
3.  **Use policies for authorization**: Keep permission logic out of controllers and views.
4.  **Stick to REST conventions**: Use standard actions (`index`, `show`, `new`, `create`, `edit`, `update`, `destroy`) whenever possible.
:::

## Configuration

### Controller Configuration

Controllers can be configured through the resource definition:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Controller behavior configuration
  action :publish, interaction: PublishPostInteraction

  # Query configuration
  search :title, :content
  filter :published, with: :boolean

  # Display configuration
  display :title, :author, :published_at
end
```

### Global Configuration

Core behavior can be configured globally:

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.development = Rails.env.development?
  config.cache_discovery = !Rails.env.development?
end
```

## Error Handling

The Core module provides comprehensive error handling:

### Common Errors

- **AuthorizationError**: When user lacks permissions
- **ResourceNotFound**: When resource doesn't exist
- **ValidationError**: When resource validation fails

### Custom Error Handling

```ruby
class ApplicationController < ActionController::Base
  include Plutonium::Core::Controller

  rescue_from ActionPolicy::Unauthorized do |exception|
    render json: { error: 'Access denied' }, status: :forbidden
  end

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render json: { error: 'Resource not found' }, status: :not_found
  end
end
```

## Migration Guide

### From Rails Controllers

Converting existing Rails controllers to use Plutonium Core:

```ruby
# Before
class PostsController < ApplicationController
  def index
    @posts = Post.all
    @posts = @posts.where(published: true) if params[:published]
  end

  def show
    @post = Post.find(params[:id])
  end
end

# After
class PostsController < ApplicationController
  include Plutonium::Core::Controller

  # Most functionality handled automatically
  # through resource definition
end
```

## Related Modules

- **[Resource](./resource.md)** - Resource definitions and CRUD operations
- **[Auth](./auth.md)** - Authentication and authorization
- **[Interaction](./interaction.md)** - Business logic encapsulation
- **[UI](./ui.md)** - User interface components
