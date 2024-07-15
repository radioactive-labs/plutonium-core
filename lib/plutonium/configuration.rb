# frozen_string_literal: true

module Plutonium
  # Configuration class for Plutonium module
  #
  # @example
  #   Plutonium.configure do |config|
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

    # Initialize a new Configuration instance
    #
    # @note This method sets default values based on environment variables and Rails environment
    def initialize
      @development = parse_boolean_env("PLUTONIUM_DEV")
      @cache_discovery = !Rails.env.development?
      @enable_hotreload = Rails.env.development?
      @assets = AssetConfiguration.new
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
