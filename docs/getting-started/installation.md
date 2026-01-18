# Installation

This guide covers installing Plutonium in both new and existing Rails applications.

## New Application

The fastest way to get started is with our application template:

```bash
rails new myapp -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

This template:
- Adds the Plutonium gem
- Configures TailwindCSS 4 with Plutonium's theme
- Sets up Rodauth for authentication
- Creates initial migrations
- Configures the asset pipeline

After the template completes:

```bash
cd myapp
rails db:migrate
bin/dev
```

Visit `http://localhost:3000` to see your new application.

## Existing Application

### Step 1: Add the Gem

Add Plutonium to your Gemfile:

```ruby
gem "plutonium"
```

Then install:

```bash
bundle install
```

### Step 2: Run the Installer

```bash
rails generate pu:core:install
```

This generator:
- Creates the Plutonium initializer
- Adds required configurations
- Sets up the asset pipeline integration

### Step 3: Install Rodauth (Optional)

If you want Plutonium's built-in authentication:

```bash
rails generate pu:rodauth:install
```

This creates:
- Rodauth configuration files
- Account model and migrations
- Email templates for authentication flows

### Step 4: Run Migrations

```bash
rails db:migrate
```

### Step 5: Configure Assets

Run the assets generator to set up TailwindCSS and Plutonium styles:

```bash
rails generate pu:core:assets
```

This configures PostCSS, TailwindCSS, and imports Plutonium's styles into your application.

## Verifying Installation

After installation, verify everything is working:

```bash
rails runner "puts Plutonium::VERSION"
```

You should see the installed version number.

## Configuration

Plutonium is configured in `config/initializers/plutonium.rb`:

```ruby
Plutonium.configure do |config|
  # Load default settings for version 1.0
  config.load_defaults 1.0

  # Development mode (auto-detected from PLUTONIUM_DEV env var)
  # config.development = true

  # Cache discovery (defaults to true in production, false in development)
  # config.cache_discovery = false

  # Hot reloading (defaults to true in development)
  # config.enable_hotreload = true

  # Asset configuration
  # config.assets.logo = "custom_logo.png"
  # config.assets.favicon = "custom_favicon.ico"
  # config.assets.stylesheet = "plutonium.css"
  # config.assets.script = "plutonium.min.js"
end
```

## Development Setup

For the best development experience:

### 1. Use bin/dev

Plutonium includes a Procfile for `foreman`:

```bash
bin/dev
```

This starts Rails and the CSS watcher together.

### 2. Enable Reloading

In development, Plutonium automatically reloads definitions and policies when files change. This is controlled by `config.enable_hotreload` (enabled by default in development).

## Next Steps

Now that Plutonium is installed:

- [Create your first Feature Package](/guides/creating-packages)
- [Generate a Resource](/guides/adding-resources)
- [Follow the Tutorial](/getting-started/tutorial/)
