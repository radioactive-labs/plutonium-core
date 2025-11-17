# Installation and Setup

::: tip VERSION REQUIREMENTS
- Ruby 3.2.2 or higher
- Rails 7.1 or higher
- Node.js and Yarn
:::

## Quick Start

Get up and running with Plutonium in seconds:

::: code-group
```bash [New App]
rails new plutonium_app -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

```bash [Existing App]
bin/rails app:template \
  LOCATION=https://radioactive-labs.github.io/plutonium-core/templates/base.rb
```
:::

## Detailed Installation Guide

1. Add Plutonium to your Gemfile:

::: code-group
```ruby [Gemfile]
gem "plutonium"
```

```bash [Terminal]
bundle install
```
:::

2. Run the installation generator:

```bash
rails generate pu:core:install
```

This will:
- Set up the basic Plutonium structure
- Create necessary configuration files
- Configure your application for Plutonium

### Project Structure

After installation, your project will have the following new directories and files:

```
my_rails_app/
├── app/
│   ├── controllers/
│   │   ├── plutonium_controller.rb     # Base controller for Plutonium
│   │   └── resource_controller.rb      # Base controller for resources
│   ├── definitions/
│   │   └── resource_definition.rb      # Base class for resource definitions
│   ├── interactions/
│   │   └── resource_interaction.rb     # Base class for resource interactions
│   ├── models/
│   │   └── resource_record.rb         # Base module for resource models
│   ├── policies/
│   │   └── resource_policy.rb         # Base class for resource policies
│   └── views/
│       └── layouts/
│           └── resource.html.erb       # Base layout for resources
├── config/
│   ├── initializers/
│   │   └── plutonium.rb               # Main configuration
│   └── packages.rb                    # Package registration
└── packages/                          # Directory for modular features
    └── .keep
```

## Configuration

### Basic Configuration

Configure Plutonium in `config/initializers/plutonium.rb`:

```ruby
Plutonium.configure do |config|
  # Load default configuration for version 1.0
  config.load_defaults 1.0

  # Asset configuration
  config.assets.stylesheet = "plutonium.css" # Default stylesheet
  config.assets.script = "plutonium.js"     # Default JavaScript
  config.assets.logo = "plutonium.png"   # Default logo
end
```

### Authentication Setup

Plutonium supports multiple authentication strategies. Here's how to set up the recommended Rodauth integration:

1. Install Rodauth:

```bash
rails generate pu:rodauth:install
```

2. Create an authentication account:

::: code-group
```bash [Basic Setup]
rails generate pu:rodauth:account user
```

```bash [Custom Setup]
# Include selected authentication features
rails generate pu:rodauth:account admin --no-defaults \
  --login --logout --remember --lockout \
  --create-account --verify-account --close-account \
   --change-password --reset-password --reset-password-notify \
  --active-sessions --password-grace-period --otp \
  --recovery-codes --audit-logging --internal-request
```
:::

3. Configure the authentication controller:

```ruby
# app/controllers/resource_controller.rb
class ResourceController < PlutoniumController
  include Plutonium::Resource::Controller
  include Plutonium::Auth::Rodauth(:user)
end
```

::: tip
You can use your existing authentication system by implementing the `current_user` method in `ResourceController`.
:::

## Optional Enhancements

### Database Performance

For PostgreSQL/MySQL users, add these recommended gems:

```ruby
group :development, :test do
  # N+1 query detection
  gem "prosopite"
end

# Automatic eager loading
gem "goldiloader"
```

### Development Tools

Add helpful development gems:

```ruby
# Generate model annotations
rails generate pu:gem:annotated

# Set up environment variables
rails generate pu:gem:dotenv
```
