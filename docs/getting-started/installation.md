# Installation

For full installation reference (configuration options, base classes, what `pu:core:install` creates), see [Reference › App](/reference/app/). This page covers the quickest path.

## New application

```bash
rails new myapp -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

This sets up Rails with Propshaft, esbuild, TailwindCSS, and Plutonium — plus Rodauth auth, asset pipeline, and initial migrations.

After the template completes:

```bash
cd myapp
rails db:migrate
bin/dev
```

Visit `http://localhost:3000`.

## Existing application

::: danger Use `base.rb`, not `plutonium.rb`
The `plutonium.rb` template re-runs full app bootstrap (dotenv, annotate, solid_*, asset config) and creates generic "initial commit" commits that clobber history. For any pre-existing app, always use `base.rb`.
:::

### Option 1: Template

```bash
bin/rails app:template \
  LOCATION=https://radioactive-labs.github.io/plutonium-core/templates/base.rb
```

### Option 2: Manual

```ruby
# Gemfile
gem "plutonium"
```

```bash
bundle install
rails generate pu:core:install
```

## Optional: authentication

```bash
rails generate pu:rodauth:install
rails generate pu:rodauth:account user
rails db:migrate
```

For account options and customization, see [Reference › Auth](/reference/auth/) and [Guides › Authentication](/guides/authentication).

## Optional: assets toolchain

```bash
rails generate pu:core:assets
```

Installs npm packages, creates `tailwind.config.js` extending Plutonium's config, imports Plutonium CSS, registers Stimulus controllers. Required if you want to customize the theme — see [Reference › UI › Assets](/reference/ui/assets) and [Guides › Theming](/guides/theming).

## Verify

```bash
rails runner "puts Plutonium::VERSION"
```

## Configuration

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.load_defaults 1.0

  # config.shell = :classic            # legacy chrome (only for upgrades)

  # Custom assets (after running pu:core:assets)
  # config.assets.stylesheet = "application"
  # config.assets.script     = "application"
  # config.assets.logo       = "custom_logo.png"
  # config.assets.favicon    = "custom_favicon.ico"
end
```

Full configuration options: [Reference › App](/reference/app/#configuration).

## `bin/dev` for development

Plutonium ships a Procfile that runs Rails and the CSS watcher together:

```bash
bin/dev
```

## Next steps

- [Tutorial](./tutorial/) — build a complete blog application step-by-step
- [Adding resources](/guides/adding-resources) — create your first resource
- [Creating packages](/guides/creating-packages) — organize code into feature and portal packages
