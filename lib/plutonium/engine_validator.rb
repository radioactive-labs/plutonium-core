# frozen_string_literal: true

module Plutonium
  module EngineValidator
    extend ActiveSupport::Concern

    private

    class_methods do
      # Validates that the current engine supports Plutonium features.
      #
      # @raise [ArgumentError] If the engine doesn't include Plutonium::Application::Engine.
      # @return [void]
      def validate_engine!(engine)
        return if supported_engine?(engine)

        # TODO: make the error link to documentation on how to ensure that your engine is supported
        raise ArgumentError, "#{engine} must include Plutonium::Application::Engine to call register resources"
      end

      # Checks if the current engine supports Plutonium features.
      #
      # @return [Boolean] True if the engine includes Plutonium::Pkg::App, false otherwise.
      def supported_engine?(engine)
        engine.include?(Plutonium::Application::Engine)
      end
    end
  end
end
