---
title: Configuration Module
---

# Configuration Module

The Configuration module provides centralized configuration management for Plutonium applications. It allows you to customize various aspects of Plutonium's behavior through a clean, versioned configuration API with environment-specific settings and asset management.

::: tip
The main configuration file is located at `config/initializers/plutonium.rb`.
:::

## Overview

- **Centralized Configuration**: Single point of configuration for all Plutonium settings.
- **Version-Based Defaults**: Versioned configuration system for backward compatibility.
- **Asset Configuration**: Centralized asset path and file management.
- **Environment Variables**: Support for environment-based configuration.
- **Development Features**: Hot reloading and development-specific settings.
- **Rails Integration**: Seamless integration with Rails configuration system.

## Basic Configuration

All configuration happens within the `Plutonium.configure` block in `config/initializers/plutonium.rb`.

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  # Load version-specific defaults first
  config.load_defaults 1.0

  # Core settings
  config.development = Rails.env.development?
  config.cache_discovery = !Rails.env.development?
  config.enable_hotreload = Rails.env.development?

  # Asset configuration
  config.assets.logo = "custom_logo.png"
  config.assets.favicon = "custom_favicon.ico"
  config.assets.stylesheet = "custom_plutonium.css"
  config.assets.script = "custom_plutonium.js"
end
```

## Configuration Options

### Core Settings

::: code-group
```ruby [config.development]
# Controls whether Plutonium operates in development mode.
# Can also be set via PLUTONIUM_DEV environment variable.
config.development = Rails.env.development?
```
```ruby [config.cache_discovery]
# Controls whether resource discovery is cached.
# Typically disabled in development for faster iteration.
config.cache_discovery = !Rails.env.development?
```
```ruby [config.enable_hotreload]
# Controls whether hot reloading is enabled.
# Only recommended for development environments.
config.enable_hotreload = Rails.env.development?
```
:::

### Asset Configuration

All asset paths are relative to your application's asset directories.

::: code-group
```ruby [config.assets.logo]
# Path to the logo file.
config.assets.logo = "custom_logo.svg" # default: "plutonium.png"
```
```ruby [config.assets.favicon]
# Path to the favicon file.
config.assets.favicon = "custom_favicon.ico" # default: "plutonium.ico"
```
```ruby [config.assets.stylesheet]
# Path to the main stylesheet.
config.assets.stylesheet = "custom_theme.css" # default: "plutonium.css"
```
```ruby [config.assets.script]
# Path to the main JavaScript file.
config.assets.script = "custom_plutonium.js" # default: "plutonium.min.js"
```
:::

## Version Management

Plutonium uses a versioned configuration system to maintain backward compatibility. When upgrading, you can update the version number to adopt new defaults without breaking your existing setup.

```ruby
Plutonium.configure do |config|
  # Load defaults for version 1.0
  config.load_defaults 1.0

  # Override specific settings after loading defaults
  config.assets.logo = "custom_logo.png"
end
```

::: details Version History
- **1.0**: Initial configuration version with base settings for development, caching, and asset management.
:::

## Environment Variables

Some configuration options can be controlled via environment variables.

::: code-group
```bash [PLUTONIUM_DEV]
# Enable development mode
export PLUTONIUM_DEV=true

# Disable development mode
export PLUTONIUM_DEV=false
```
```ruby [Implementation]
# This is automatically parsed as a boolean:
config.development = parse_boolean_env("PLUTONIUM_DEV")
```
:::

::: details Adding Custom Environment Variables
You can extend the configuration object to support your own environment variables.
```ruby
class CustomConfiguration < Plutonium::Configuration
  attr_accessor :api_timeout, :max_file_size

  def initialize
    super
    @api_timeout = parse_integer_env("PLUTONIUM_API_TIMEOUT", default: 30)
    @max_file_size = parse_integer_env("PLUTONIUM_MAX_FILE_SIZE", default: 10.megabytes)
  end

  private

  def parse_integer_env(env_var, default:)
    ENV[env_var]&.to_i || default
  end
end
```
:::

## Asset Management

### Custom Assets

To use your own assets, place them in the appropriate `app/assets` directory and update the configuration in `plutonium.rb`.

::: code-group
```ruby [config/initializers/plutonium.rb]
Plutonium.configure do |config|
  config.assets.logo = "custom_logo.png"
  config.assets.stylesheet = "custom_theme.css"
end
```
```bash [File Structure]
app/assets/
├── images/
│   └── custom_logo.png
└── stylesheets/
    └── custom_theme.css
```
:::

### Asset Precompilation

Plutonium automatically adds its default assets to the precompile list.

::: details Precompilation Control
To exclude default Plutonium assets from precompilation (for example, if you are providing your own builds), you can modify the precompile list.
```ruby
# config/initializers/assets.rb
Rails.application.config.after_initialize do
  Rails.application.config.assets.precompile -= Plutonium::Railtie::PRECOMPILE_ASSETS
end
```
The `PRECOMPILE_ASSETS` constant contains a list of all default asset files.
:::

## Development Features

### Hot Reloading

Enable automatic reloading of Plutonium components during development:

```ruby
Plutonium.configure do |config|
  config.enable_hotreload = Rails.env.development?
end

# This starts the Plutonium::Reloader in after_initialize
```

### Development Asset Server

In development mode, Plutonium can serve assets directly from the source:

```ruby
# Automatically configured when development = true
if Plutonium.configuration.development?
  config.app_middleware.insert_before(
    ActionDispatch::Static,
    Rack::Static,
    urls: ["/build"],
    root: Plutonium.root.join("src").to_s
  )
end
```

### Cache Discovery

Control resource discovery caching for development speed:

```ruby
Plutonium.configure do |config|
  # Disable caching in development for faster iteration
  config.cache_discovery = !Rails.env.development?

  # Or force enable for testing cache behavior
  config.cache_discovery = true
end
```

## Environment-Specific Configuration

### Development Configuration

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.load_defaults 1.0

  if Rails.env.development?
    config.development = true
    config.cache_discovery = false
    config.enable_hotreload = true

    # Development-specific assets
    config.assets.stylesheet = "plutonium_dev.css"
  end
end
```

### Production Configuration

```ruby
Plutonium.configure do |config|
  config.load_defaults 1.0

  if Rails.env.production?
    config.development = false
    config.cache_discovery = true
    config.enable_hotreload = false

    # Production-optimized assets
    config.assets.script = "plutonium.min.js"
    config.assets.stylesheet = "plutonium.min.css"
  end
end
```

### Test Configuration

```ruby
Plutonium.configure do |config|
  config.load_defaults 1.0

  if Rails.env.test?
    config.development = false
    config.cache_discovery = false
    config.enable_hotreload = false

    # Test-specific settings for speed
    config.assets.script = "plutonium_test.js"
  end
end
```

## Advanced Configuration

### Custom Configuration Classes

Extend the configuration system with custom options:

```ruby
# lib/my_app/configuration.rb
module MyApp
  class Configuration < Plutonium::Configuration
    attr_accessor :custom_feature_enabled
    attr_accessor :api_timeout
    attr_accessor :theme_mode

    def initialize
      super
      @custom_feature_enabled = false
      @api_timeout = 30
      @theme_mode = "auto"
    end

    def load_defaults(version)
      super

      # Custom defaults for your application
      case version
      when 1.0
        @custom_feature_enabled = true
        @theme_mode = "light"
      end
    end
  end
end

# Replace Plutonium's configuration
Plutonium.instance_variable_set(:@configuration, MyApp::Configuration.new)
```

### Conditional Configuration

Apply configuration based on various conditions:

```ruby
Plutonium.configure do |config|
  config.load_defaults 1.0

  # Feature flags from environment
  config.development = Rails.env.development? || ENV['FORCE_DEV_MODE'] == 'true'

  # Multi-tenant asset configuration
  if defined?(Current) && Current.tenant&.custom_branding?
    config.assets.logo = "tenant_#{Current.tenant.id}_logo.png"
    config.assets.stylesheet = "tenant_#{Current.tenant.id}_theme.css"
  end

  # Performance settings based on server capacity
  if ENV['SERVER_TIER'] == 'high'
    config.cache_discovery = true
    config.enable_hotreload = false
  elsif ENV['SERVER_TIER'] == 'development'
    config.cache_discovery = false
    config.enable_hotreload = true
  end
end
```

### Configuration Validation

Add validation to ensure configuration integrity:

```ruby
class ValidatedConfiguration < Plutonium::Configuration
  def validate!
    raise "Logo file not found: #{assets.logo}" unless logo_exists?
    raise "Invalid theme" unless %w[light dark auto].include?(theme_mode)
    raise "API timeout must be positive" unless api_timeout > 0
  end

  private

  def logo_exists?
    Rails.application.assets.find_asset(assets.logo) ||
      File.exist?(Rails.root.join("app/assets/images", assets.logo))
  end
end
```

## Integration with Rails

### Railtie Integration

Configuration is integrated with Rails through the Railtie system:

```ruby
# lib/plutonium/railtie.rb
initializer "plutonium.base" do
  Rails.application.class.include Plutonium::Engine
end

initializer "plutonium.asset_server" do
  setup_development_asset_server if Plutonium.configuration.development?
end

config.after_initialize do
  Plutonium::Reloader.start! if Plutonium.configuration.enable_hotreload
  Plutonium::Loader.eager_load if Rails.env.production?
end
```

### Engine Configuration

Configuration affects how Plutonium engines behave:

```ruby
# Conditional middleware setup based on configuration
if Plutonium.configuration.development?
  config.app_middleware.insert_before(
    ActionDispatch::Static,
    Rack::Static,
    urls: ["/build"],
    root: Plutonium.root.join("src").to_s
  )
end
```

## Testing Configuration

### Test Environment Setup

```ruby
# spec/spec_helper.rb or test/test_helper.rb
Plutonium.configure do |config|
  config.load_defaults 1.0
  config.development = false
  config.cache_discovery = false
  config.enable_hotreload = false

  # Test-specific asset configuration
  config.assets.logo = "test_logo.png"
  config.assets.stylesheet = "test_theme.css"
end
```

### Configuration Testing

```ruby
RSpec.describe 'Plutonium configuration' do
  let(:config) { Plutonium::Configuration.new }

  describe '#load_defaults' do
    it 'loads version 1.0 defaults' do
      config.load_defaults 1.0
      expect(config.defaults_version).to eq(1.0)
    end

    it 'raises error for unknown version' do
      expect { config.load_defaults 2.0 }.to raise_error(/No applicable defaults/)
    end
  end

  describe 'asset configuration' do
    it 'has default asset paths' do
      expect(config.assets.logo).to eq("plutonium.png")
      expect(config.assets.favicon).to eq("plutonium.ico")
      expect(config.assets.stylesheet).to eq("plutonium.css")
      expect(config.assets.script).to eq("plutonium.min.js")
    end

    it 'allows custom asset configuration' do
      config.assets.logo = "custom_logo.svg"
      expect(config.assets.logo).to eq("custom_logo.svg")
    end
  end

  describe 'environment variable parsing' do
    around do |example|
      original_env = ENV["PLUTONIUM_DEV"]
      example.run
      ENV["PLUTONIUM_DEV"] = original_env
    end

    it 'parses PLUTONIUM_DEV as boolean' do
      ENV["PLUTONIUM_DEV"] = "true"
      config = Plutonium::Configuration.new
      expect(config.development?).to be true

      ENV["PLUTONIUM_DEV"] = "false"
      config = Plutonium::Configuration.new
      expect(config.development?).to be false
    end
  end
end
```

### Configuration Helpers

```ruby
# spec/support/configuration_helpers.rb
module ConfigurationHelpers
  def with_plutonium_config(**options)
    original_config = Plutonium.configuration.dup

    options.each do |key, value|
      if key.to_s.include?('.')
        # Handle nested configuration like 'assets.logo'
        keys = key.to_s.split('.')
        target = keys[0..-2].reduce(Plutonium.configuration) { |config, k| config.send(k) }
        target.send("#{keys.last}=", value)
      else
        Plutonium.configuration.send("#{key}=", value)
      end
    end

    yield
  ensure
    Plutonium.instance_variable_set(:@configuration, original_config)
  end
end

# Usage in tests
RSpec.describe "Feature with custom config" do
  include ConfigurationHelpers

  it "works with development mode enabled" do
    with_plutonium_config(development: true, enable_hotreload: true) do
      # Test behavior with development mode
    end
  end

  it "works with custom assets" do
    with_plutonium_config('assets.logo' => 'custom.png') do
      # Test behavior with custom logo
    end
  end
end
```

## Best Practices

### Configuration Organization

1. **Use initializers**: Place configuration in `config/initializers/plutonium.rb`
2. **Load defaults first**: Always call `load_defaults` before customizing settings
3. **Environment-specific**: Use environment checks for conditional configuration
4. **Document custom settings**: Comment any non-standard configuration options

### Performance Considerations

1. **Cache in production**: Enable `cache_discovery` in production environments
2. **Disable dev features**: Turn off development features in production
3. **Optimize assets**: Use minified assets for production
4. **Selective hot reload**: Only enable hot reloading in development

### Security Considerations

1. **Environment variables**: Use environment variables for sensitive configuration
2. **Validate asset paths**: Ensure custom asset paths are safe and exist
3. **Production mode**: Never enable development mode in production
4. **Access control**: Restrict who can modify configuration in production

### Maintenance Guidelines

1. **Version compatibility**: Test configuration changes across supported versions
2. **Gradual adoption**: Introduce new configuration options incrementally
3. **Backward compatibility**: Maintain compatibility when adding new options
4. **Documentation**: Keep configuration documentation up to date

## Migration and Upgrade Guide

### Upgrading Configuration Versions

When upgrading Plutonium versions:

```ruby
# Before (v1.0)
Plutonium.configure do |config|
  config.development = Rails.env.development?
  config.cache_discovery = !Rails.env.development?
  # ... other settings
end

# After (hypothetical v1.1)
Plutonium.configure do |config|
  config.load_defaults 1.1  # Load new version defaults
  config.development = Rails.env.development?
  config.cache_discovery = !Rails.env.development?
  # ... existing settings
  # ... any new v1.1 features
end
```

### Configuration File Migration

When moving from older configuration approaches:

```ruby
# Old approach (deprecated)
Rails.application.configure do
  config.plutonium.development = true
end

# New approach (recommended)
Plutonium.configure do |config|
  config.load_defaults 1.0
  config.development = true
end
```

## Integration Points

- **Core Module**: Configuration affects core controller behavior and features
- **Asset Module**: Asset configuration controls frontend resource loading
- **Portal Module**: Configuration can affect portal-specific behaviors
- **Authentication Module**: Development settings affect authentication flows
- **Resource Module**: Cache settings affect resource discovery and loading

The Configuration module provides a flexible, extensible foundation for customizing Plutonium behavior while maintaining compatibility and providing sensible defaults for different environments.
