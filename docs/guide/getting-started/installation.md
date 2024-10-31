# Installation and Setup

::: tip VERSION REQUIREMENTS
- Ruby 3.2.2 or higher
- Rails 7.1 or higher
:::

## Quick Start

Get up and running with Plutonium in minutes:

::: code-group
```ruby [Gemfile]
gem "plutonium"
```

```bash [Terminal]
# Install the gem
bundle install

# Run the installer
rails generate pu:core:install
```
:::

## Detailed Installation Guide

### Adding Plutonium to an Existing Rails Application

1. Add Plutonium to your Gemfile:

::: code-group
```ruby [Gemfile]
gem "plutonium"

# Optional but recommended for PostgreSQL/MySQL users
gem "goldiloader" # Automatic eager loading
gem "prosopite"  # N+1 query detection
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
- Add required JavaScript and CSS dependencies
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

::: warning
Make sure your configuration matches your environment needs.
:::

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
rails generate pu:rodauth:account user \
  --login --logout --remember --change-password \
  --create-account --verify-account --reset-password \
  --otp --recovery-codes
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
You can use your existing authentication system by implementing the `current_user` method in your `ResourceController`.
:::

<!--
## Asset Pipeline Setup

### JavaScript Setup


Plutonium uses modern JavaScript features. Here's how to set it up:

1. Install required npm packages:

::: code-group
```bash [importmap]
bin/importmap pin @radioactive-labs/plutonium
```

```bash [esbuild]
npm install @radioactive-labs/plutonium
```
:::


2. Configure JavaScript:

::: code-group
```js [app/javascript/controllers/index.js]
import { application } from "controllers/application"
import { registerControllers } from "@radioactive-labs/plutonium" // [!code ++]
registerControllers(application) // [!code ++]
```

```js [app/javascript/application.js]
import "@hotwired/turbo-rails"
import "controllers"
```
:::

### CSS Setup

Plutonium uses Tailwind CSS. Configure it in your `tailwind.config.js`:

```js
const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './app/views/**/*.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/components/**/*.{erb,rb}',
    './node_modules/@radioactive-labs/plutonium/**/*.{js,ts}'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('flowbite/plugin')
  ],
}
```
-->

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
rails generate pu:gem:annotate

# Set up environment variables
rails generate pu:gem:dotenv
```

## Verification

Verify your installation:

```bash
# Start your Rails server
rails server

# Check your logs for any warnings or errors
tail -f log/development.log

# Generate and test a sample resource
rails generate pu:res:scaffold Post title:string content:text
```

Visit `http://localhost:3000/posts` to verify everything is working.

<!--
::: tip Next Steps
Now that you have Plutonium installed and configured, you're ready to:
1. [Create your first resource](/guide/resources/creating-resources)
2. [Set up your first package](/guide/packages/creating-packages)
3. [Configure authorization](/guide/authorization/basic-setup)
:::
-->

<!--
### Getting Help

If you run into issues:

1. Check the [FAQ](/guide/faq)
2. Search [GitHub Issues](https://github.com/radioactive-labs/plutonium-core/issues)
3. Join our [Discord Community](https://discord.gg/plutonium)
4. Create a new [GitHub Issue](https://github.com/radioactive-labs/plutonium-core/issues/new)
-->
