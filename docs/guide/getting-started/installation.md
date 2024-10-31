# Installation

Plutonium ships as a gem but with extension points within your app.

## Installing Plutonium

::: warning Prerequisites
- A new or existing Rails 7.1+ application
- Ruby 3.2.2+
:::

1. Add Plutonium to your Gemfile:

```ruby
gem 'plutonium'
```

2. Install required dependencies:

```bash
bundle install
```

3. Run the installation generator:

```bash
rails generate pu:core:install
```

## Optional Performance Gems

::: tip Recommended for Postgres/MySQL Users
If you're using Postgres or MySQL, we strongly recommend installing these gems to optimize your application's performance.
:::

#### Goldiloader
[Goldiloader](https://github.com/salsify/goldiloader) automatically eager loads associations when they're used, helping prevent N+1 queries without explicit eager loading declarations. This means:

```ruby
# Without Goldiloader - Generates N+1 queries
posts.each do |post|
  puts post.author.name  # Each post triggers a query
end

# With Goldiloader - Automatically eager loads in a single query
posts.each do |post|
  puts post.author.name  # No additional queries
end
```

#### Prosopite
[Prosopite](https://github.com/charkost/prosopite) helps detect N+1 queries during development and testing. It will raise an error when it detects N+1 queries.

::: warning Note about Prosopite
Prosopite should only be enabled in development and test environments. It adds overhead that isn't appropriate for production use.
:::

## Configure Authentication

::: tip Note
You only need to perform this step if you intend to register resources in your main app (not recommended) or
wish to set a default authentication scheme.
:::

Plutonium expects a non-nil `user` per request in order to perform authorization checks.

If your `ApplicationController` inherits `ActionController::Base` and implements a `current_user` method,
this will be used by plutonium.

Otherwise, configure the `current_user` method in `app/controllers/resource_controller.rb` to return a non nil value.

```ruby
class ResourceController < PlutoniumController
  include Plutonium::Resource::Controller

  private def current_user
    raise NotImplementedError, "#{self.class}#current_user must return a non nil value" # [!code --]
    "Guest" # allow all users # [!code ++]
  end
end
```
<!--
## Verifying Installation

After installation, you can verify everything is working correctly:

1. Start your Rails server:
```bash
rails server
```

2. Check your logs for any warnings or errors related to Plutonium initialization

3. Generate and test a sample resource:
```bash
rails generate pu:res:scaffold Post title:string content:text
rails server
```

4. Visit `http://localhost:3000/posts` to verify the resource is working

::: info Troubleshooting
If you encounter any issues during installation, check:
1. Your Rails version is 7.1 or higher
2. All dependencies were installed correctly
3. The installation generator completed successfully
4. Your database is properly configured and migrated
:::
-->
