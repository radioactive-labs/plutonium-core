# frozen_string_literal: true

module Plutonium
  # Configuration class for Plutonium module
  #
  # @example
  #   Plutonium.configure do |config|
  #     config.load_defaults 1.0
  #     config.development = true
  #     config.cache_discovery = false
  #     config.enable_hotreload = true
  #     config.assets.logo = "custom_logo.png"
  #   end
  class Configuration
    # @return [Boolean] whether Plutonium is in development mode
    attr_accessor :development

    # @return [Boolean] whether to cache discovery
    attr_accessor :cache_discovery

    # @return [Boolean] whether to enable hot reloading
    attr_accessor :enable_hotreload

    # @return [AssetConfiguration] asset configuration
    attr_reader :assets

    # @return [Plutonium::Wizard::Configuration] wizard subsystem configuration
    attr_reader :wizards

    # @return [Float] the current defaults version
    attr_reader :defaults_version

    # @return [Symbol] :modern (Topbar/IconRail, default), :plain (Topbar, no
    #   icon rail), or :classic (legacy Header/Sidebar).
    attr_accessor :shell

    # @return [String] host URL of the Navii avatar service (no path), used by
    #   {Plutonium::UI::Avatar} as the default profile-image fallback. The
    #   component appends the `/avatar/:seed` route. Repoint this to self-host
    #   or proxy the service.
    attr_accessor :navii_host_url

    # @return [String, false, nil] the currency unit (symbol) used when rendering
    #   a currency value that has no unit configured on `has_cents` or the display.
    #   `nil` (default) falls back to the i18n `number.currency.format.unit` when
    #   the locale defines it, otherwise no symbol. Set a literal like `"£"` to
    #   change the default, or `false` (or `""`) for no symbol application-wide.
    attr_accessor :default_currency_unit

    # @return [String, nil] the default country (ISO2 code, e.g. "gh") for phone
    #   (`as: :phone`) inputs that don't set their own `initial_country:`. `nil`
    #   (default) leaves it to the intl-tel-input library (no country preselected).
    #   Stored verbatim — read it back exactly as set. Consumers that feed
    #   intl-tel-input should use {#normalized_default_phone_country}.
    attr_reader :default_phone_country

    # @return [String, nil] {#default_phone_country} downcased to the lowercase
    #   ISO2 form intl-tel-input expects, so callers can set "GH" or "gh"
    #   interchangeably. `nil` stays `nil`. Computed once on assignment.
    attr_reader :normalized_default_phone_country

    def default_phone_country=(value)
      @default_phone_country = value
      @normalized_default_phone_country = value&.downcase
    end

    # Map of version numbers to their default configurations
    VERSION_DEFAULTS = {
      1.0 => proc do |config|
        # No changes for 1.0 yet as it's the current base configuration
      end
      # Add more version configurations here as needed
      # 1.1 => proc do |config|
      #   config.some_new_setting = true
      # end
    }.freeze

    # Initialize a new Configuration instance
    #
    # @note This method sets initial values
    def initialize
      @defaults_version = nil
      @assets = AssetConfiguration.new
      @wizards = Plutonium::Wizard::Configuration.new

      @development = parse_boolean_env("PLUTONIUM_DEV")
      @cache_discovery = !Rails.env.development?
      @enable_hotreload = Rails.env.development?
      @shell = :modern
      @navii_host_url = "https://api.navii.dev"
    end

    # Load default configuration for a specific version
    #
    # @param version [Float] the version to load defaults for
    # @return [void]
    def load_defaults(version)
      available_versions = VERSION_DEFAULTS.keys.sort
      applicable_versions = available_versions.select { |v| v <= version }

      if applicable_versions.empty?
        raise "No applicable defaults found for version #{version}."
      end

      applicable_versions.each do |v|
        VERSION_DEFAULTS[v].call(self)
      end

      @defaults_version = applicable_versions.last
    end

    # whether Plutonium is in development mode
    #
    # @return [Boolean]
    def development?
      @development
    end

    private

    # Parse boolean environment variable
    #
    # @param env_var [String] name of the environment variable
    # @return [Boolean] parsed boolean value
    def parse_boolean_env(env_var)
      ActiveModel::Type::Boolean.new.cast(ENV[env_var]).present?
    end

    # Asset configuration for Plutonium
    class AssetConfiguration
      # @return [String] path to logo file
      attr_accessor :logo

      # @return [String] path to favicon file
      attr_accessor :favicon

      # @return [String] path to stylesheet file
      attr_accessor :stylesheet

      # @return [String] path to JavaScript file
      attr_accessor :script

      # Initialize a new AssetConfiguration instance with default values
      def initialize
        @logo = "plutonium.png"
        @favicon = "plutonium.ico"
        @stylesheet = "plutonium.css"
        @script = "plutonium.min.js"
      end
    end
  end

  class << self
    # Get the current configuration
    #
    # @return [Configuration] current configuration instance
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure Plutonium
    #
    # @yield [config] Configuration instance
    # @yieldparam config [Configuration] current configuration instance
    # @return [void]
    def configure
      yield(configuration)
    end
  end
end
