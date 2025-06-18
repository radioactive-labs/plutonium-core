---
title: Package Module
---

# Package Module

The Package module provides the foundation for modular application organization in Plutonium. It enables Rails engines to work within the Plutonium ecosystem by providing specialized engine configuration and view path management.

::: tip
The core of the Package module is `Plutonium::Package::Engine`, which should be included in your package's `engine.rb` file.
:::

## Overview

- **Engine Foundation**: Provides base functionality for all Plutonium packages (which are Rails Engines).
- **View Path Control**: Manages view lookups for proper isolation between packages.
- **Migration Management**: Automatically includes package migrations in the application's migration path.

## Usage

The primary way to use the Package module is by including `Plutonium::Package::Engine` in your package's engine file. This is handled automatically by the generators.

::: code-group
```bash [Generate a Feature Package]
rails generate pu:pkg:package blogging
```
```ruby [packages/blogging/lib/engine.rb]
module Blogging
  class Engine < Rails::Engine
    # This inclusion provides the core package functionality.
    include Plutonium::Package::Engine
  end
end
```
:::

::: code-group
```bash [Generate a Portal Package]
rails generate pu:pkg:portal admin
```
```ruby [packages/admin_portal/lib/engine.rb]
module AdminPortal
  class Engine < Rails::Engine
    # Portal::Engine includes Package::Engine, so you get both.
    include Plutonium::Portal::Engine
  end
end
```
:::

## Key Features

### View Path Management

The Package module intentionally prevents Rails from automatically adding a package's view paths to the global lookup. Instead, view resolution is handled at the controller level by Plutonium's `Bootable` concern. This provides finer-grained control and ensures that packages remain isolated.

### Migration Integration

Package migrations are automatically detected and added to the application's main `db/migrate` path. This allows you to run `rails db:migrate` from your application root, and it will correctly process migrations from all your packages.

::: details Package Engine Implementation
The `Plutonium::Package::Engine` concern handles this automatically.
```ruby
# lib/plutonium/package/engine.rb
module Plutonium
  module Package
    module Engine
      extend ActiveSupport::Concern

      included do
        # This block hijacks the default Rails view path initializer
        # and replaces it with an empty one, giving Plutonium control.
        config.before_configuration do
          # ... logic to find and disable the default `add_view_paths` initializer
        end

        # This initializer appends the package's migrations to the host app.
        initializer :append_migrations do |app|
          unless app.root.to_s.match root.to_s
            config.paths["db/migrate"].expanded.each do |expanded_path|
              app.config.paths["db/migrate"] << expanded_path
            end
          end
        end
      end
    end
  end
end
```
:::

## Package Loading

Packages are loaded automatically via `config/packages.rb`, which is created by the `pu:core:install` generator. This file simply finds and loads all `engine.rb` files within your `packages/` directory.

```ruby
# config/packages.rb
# This file is required in `config/application.rb`

Dir.glob(File.expand_path("../packages/**/lib/engine.rb", __dir__)) do |package|
  load package
end
```

::: tip
You can package and ship your packages as gems.
:::

## Generator Integration

### Package Generator

```bash
# Create a feature package
rails generate pu:pkg:package blogging
```

Generates the basic structure with `Plutonium::Package::Engine` included.

### Portal Generator

```bash
# Create a portal package
rails generate pu:pkg:portal admin
```

Generates a portal structure with `Plutonium::Portal::Engine` (which includes Package::Engine).

## Package Types

The package system supports two main types:

1. **Feature Packages**: Business logic packages that include `Plutonium::Package::Engine`
2. **Portal Packages**: User interface packages that include `Plutonium::Portal::Engine`

Both types benefit from the foundational features provided by the Package module.

## Best Practices

1. **Use Generators**: Always use `pu:pkg:package` or `pu:pkg:portal` generators
2. **Namespace Consistency**: Keep package names consistent with their directory structure
3. **Migration Organization**: Place package-specific migrations in the package's `db/migrate` directory
4. **Engine Simplicity**: Keep engine.rb files minimal - they're just configuration points

## Integration with Other Modules

The Package module works closely with:
- **Portal Module**: Provides the foundation for portal functionality
- **Generator Module**: Scaffolds package structure
- **Core Module**: Integrates with controller bootable system
- **Routing Module**: Supports resource registration within packages
