# frozen_string_literal: true

require "zeitwerk"
require_relative "plutonium/configuration"

# Plutonium module
#
# This module provides the main functionality for the Plutonium gem.
# It sets up autoloading using Zeitwerk and provides utility methods
# for accessing gem-related information.
module Plutonium
  # Custom error class for Plutonium-specific exceptions
  class Error < StandardError; end

  # Set up Zeitwerk loader for the Plutonium gem
  # @return [Zeitwerk::Loader] configured Zeitwerk loader instance
  ZEITWERK_LOADER = Zeitwerk::Loader.for_gem(warn_on_extra_files: false).tap do |loader|
    loader.ignore("#{__dir__}/generators")
    loader.ignore("#{__dir__}/plutonium/railtie.rb")
    loader.enable_reloading if defined?(Rails.env) && Rails.env.development?
    loader.setup
  end

  class << self
    # Get the root directory of the gem
    #
    # @return [Pathname] the root directory path
    def root
      @root ||= Pathname.new(File.expand_path("..", __dir__))
    end

    # Get the root directory of the lib folder of the gem
    #
    # @return [Pathname] the lib root directory path
    def lib_root
      @lib_root ||= root.join("lib", "plutonium")
    end

    # Get the Rails logger
    #
    # @return [Logger] the Rails logger instance
    def logger
      Rails.logger
    end

    # Get the name of the application
    #
    # @return [String] the application name
    def application_name
      @application_name || Rails.application.class.module_parent_name
    end

    # Set the name of the application
    #
    # @param [String] name the name of the application
    attr_writer :application_name

    # Eager load Rails application if not already eager loaded
    #
    # @return [void]
    def eager_load_rails!
      return if @rails_eager_loaded || Rails.application.config.eager_load

      Rails.application.eager_load!
      @rails_eager_loaded = true
    end
  end
end

# Load Railtie if Rails is defined
require_relative "plutonium/railtie" if defined?(Rails::Railtie)
