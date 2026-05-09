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

    # @return [Float] the current defaults version
    attr_reader :defaults_version

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

      @development = parse_boolean_env("PLUTONIUM_DEV")
      @cache_discovery = !Rails.env.development?
      @enable_hotreload = Rails.env.development?
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
      DEFAULTS = {
        logo: "plutonium.png",
        favicon: "plutonium.ico",
        stylesheet: "plutonium.css",
        script: "plutonium.min.js"
      }.freeze

      # @return [String] path to logo file
      # @return [String] path to favicon file
      # @return [String] path to stylesheet file
      # @return [String] path to JavaScript file

      def initialize
        @customized = {}
        DEFAULTS.each { |key, value| instance_variable_set(:"@#{key}", value) }
      end

      DEFAULTS.each_key do |attr|
        attr_reader attr

        define_method(:"#{attr}=") do |value|
          @customized[attr] = true
          instance_variable_set(:"@#{attr}", value)
        end
      end

      # Whether the given asset attribute was set explicitly by user code.
      #
      # An asset is considered customized once any value is assigned to it,
      # even if that value happens to equal the default. The dev-mode asset
      # URL override (see Plutonium::Helpers::AssetsHelper#resource_asset_url_for)
      # only applies to attributes that have NOT been customized.
      #
      # @param attr [Symbol] one of :logo, :favicon, :stylesheet, :script
      # @return [Boolean]
      def customized?(attr)
        @customized.fetch(attr, false)
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
