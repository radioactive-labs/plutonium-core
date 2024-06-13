require "zeitwerk"

# Zeitwerk loader setup for the Plutonium gem
loader = Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
loader.ignore("#{__dir__}/generators")
loader.ignore("#{__dir__}/plutonium/railtie.rb")
loader.enable_reloading if defined?(Rails.env) && Rails.env.development?
loader.setup

require_relative "plutonium/railtie" if defined?(Rails::Railtie)

module Plutonium
  # Custom error class for the Plutonium module
  class Error < StandardError; end

  class << self
    # @return [Pathname] the root directory of the gem
    def root
      Pathname.new(File.expand_path("..", __dir__))
    end

    # @return [Pathname] the root directory of the lib folder of the gem
    def lib_root
      root.join("lib", "plutonium")
    end

    # @return [Logger] the Rails logger
    def logger
      Rails.logger
    end

    # @return [String] the name of the application
    def application_name
      @application_name || Rails.application.class.module_parent_name
    end

    # @param [String] application_name the name of the application
    # @return [void]
    attr_writer :application_name

    # @return [Boolean] whether the gem is in development mode
    def development?
      ActiveModel::Type::Boolean.new.cast(ENV["PLUTONIUM_DEV"]).present?
    end

    # Eager loads Rails application if not already eager loaded
    # @return [void]
    def eager_load_rails!
      return if Rails.env.production? && defined?(@rails_eager_loaded)

      Rails.application.eager_load! unless Rails.application.config.eager_load
      @rails_eager_loaded = true
    end
  end
end

Plutonium::ZEITWERK_LOADER = loader
