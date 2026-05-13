# App Reference

How a Plutonium app is assembled: installation, the package system (feature vs portal), portal engines, route registration, and connecting resources to portals.

## Sub-pages

- [Packages](./packages) — feature vs portal packages, structure, namespacing, package loading
- [Portals](./portals) — portal engines, mounting, controller concerns, `register_resource` (including singular and custom routes), connecting resources via `pu:res:conn`
- [Generators](./generators) — full `pu:*` generator catalog

## Installation

### New Rails app (recommended)

```bash
rails new myapp -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

Configures Rails + Propshaft + esbuild + TailwindCSS + Plutonium in one shot.

### Existing Rails app

::: danger Existing app → `base.rb`, not `plutonium.rb`
The `plutonium.rb` template re-runs the full app bootstrap (dotenv, annotate, solid_*, asset config) and creates generic "initial commit" commits that clobber history. For any pre-existing app, always use `base.rb`.
:::

```bash
# Template
bin/rails app:template \
  LOCATION=https://radioactive-labs.github.io/plutonium-core/templates/base.rb

# Or manual — add `gem "plutonium"` to Gemfile, then:
bundle install
rails generate pu:core:install
```

## Full setup workflow

```bash
# 1. Core install — base controllers, policies, definitions, layouts
rails generate pu:core:install

# 2. Auth (if needed)
rails generate pu:rodauth:install
rails generate pu:rodauth:account user

# 3. Portal
rails generate pu:pkg:portal admin --auth=user

# 4. First resource
rails generate pu:res:scaffold Post user:belongs_to title:string 'content:text?' --dest=main_app
rails db:migrate

# 5. Connect resource to portal
rails generate pu:res:conn Post --dest=admin_portal

# 6. Mount portal in config/routes.rb
#    mount AdminPortal::Engine, at: "/admin"

# 7. Start
bin/dev   # uses Procfile to run Rails + CSS watcher
```

Visit `http://localhost:3000/admin`.

## What `pu:core:install` creates

```
app/
├── controllers/
│   ├── plutonium_controller.rb     # non-resource base
│   └── resource_controller.rb      # CRUD base — see Behavior › Controllers
├── definitions/resource_definition.rb
├── interactions/resource_interaction.rb
├── models/resource_record.rb       # abstract model — includes Plutonium::Resource::Record
├── policies/resource_policy.rb
└── views/layouts/resource.html.erb

config/
├── initializers/plutonium.rb
└── packages.rb                     # auto-loads packages/**/lib/engine.rb

packages/.keep
```

The base classes (`ResourceController`, `ResourcePolicy`, `ResourceDefinition`, `ResourceRecord`, `ResourceInteraction`) are where you put app-wide defaults; resource-specific subclasses come from `pu:res:scaffold`.

## Configuration

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.load_defaults 1.0

  # Hot reloading (defaults to true in development)
  # config.enable_hotreload = true

  # Cache discovery (defaults to true in production, false in development)
  # config.cache_discovery = false

  # Page chrome. Default :modern (topbar + icon rail).
  # :classic preserves the legacy header + sidebar (only when upgrading).
  # config.shell = :classic

  # Custom assets — see UI › Assets
  # config.assets.stylesheet = "custom_stylesheet"
  # config.assets.script     = "custom_script"
  # config.assets.logo       = "custom_logo.png"
  # config.assets.favicon    = "custom_favicon.ico"
end
```

## Converting an existing model to a resource

```ruby
# 1. Include the module on your model
class Post < ApplicationRecord
  include Plutonium::Resource::Record
end
```

```bash
# 2. Generate supporting files (skips model + migration)
rails g pu:res:scaffold Post --no-migration --dest=main_app

# 3. Connect to portal
rails g pu:res:conn Post --dest=admin_portal
```

## Verifying installation

```bash
rails runner "puts Plutonium::VERSION"
```

## Unattended execution

Plutonium generators are interactive by default. For scripts, agents, or CI, pass:

| Flag | Generators | Purpose |
|---|---|---|
| `--dest=main_app` / `--dest=<package>` | `pu:res:scaffold`, `pu:res:conn`, package-targeted generators | Skip "select destination" prompt |
| `--force` | any | Overwrite conflicting files (required when re-running `pu:saas:setup` or meta-generators) |
| `--auth=<account>` / `--public` / `--byo` | `pu:pkg:portal` | Skip auth-type prompt |
| `--skip-bundle` | gem-installing generators | Avoid mid-run `bundle install` |
| `--quiet` | most | Reduce output noise |

Meta-generators (`pu:saas:setup`) propagate these flags to the generators they chain. Always pass `--force` when re-running a meta-generator on an app that already has some of its outputs.

## Related

- [Packages](./packages) — feature vs portal package structure
- [Portals](./portals) — portal engines, routing, resource connection
- [Generators](./generators) — full generator reference
- [Auth](/reference/auth/) — Rodauth setup and account types
- [UI › Assets](/reference/ui/assets) — Tailwind, Stimulus, design tokens
- [Tutorial](/getting-started/tutorial/) — step-by-step walkthrough
