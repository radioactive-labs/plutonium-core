# frozen_string_literal: true

module Plutonium
  module Engine
    module Validator
      extend ActiveSupport::Concern

      class_methods do
        # Validates that the current engine supports Plutonium features.
        #
        # @raise [ArgumentError] If the engine doesn't include Plutonium::Engine.
        # @return [void]
        def validate_engine!(engine)
          return if supported_engine?(engine)

          # TODO: make the error link to documentation on how to ensure that your engine is supported
          raise ArgumentError, "#{engine} must include Plutonium::Engine to call register resources"
        end

        # Checks if the current engine supports Plutonium features.
        #
        # @return [Boolean] True if the engine includes Plutonium::Engine, false otherwise.
        def supported_engine?(engine)
          engine.include?(Plutonium::Engine)
        end
      end
    end
  end
end
