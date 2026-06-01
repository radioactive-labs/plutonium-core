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

          raise ArgumentError,
            "#{engine} must include Plutonium::Engine to register resources. " \
            "See https://radioactive-labs.github.io/plutonium-core/reference/app/packages " \
            "for how to make an engine Plutonium-aware."
        end

        # Checks if the current engine supports Plutonium features.
        #
        # @return [Boolean] True if the engine includes Plutonium::Engine, false otherwise.
        def supported_engine?(engine)
          # Match by module name rather than object identity. In development the
          # framework is reloaded, so `Plutonium::Engine` is reassigned to a
          # fresh module object while already-loaded engines still include the
          # previous one — making an `include?(Plutonium::Engine)` identity check
          # spuriously false. A module's name survives the reassignment, so this
          # stays correct in both development and production without a branch.
          engine.ancestors.any? { |ancestor| ancestor.name == "Plutonium::Engine" }
        end
      end
    end
  end
end
