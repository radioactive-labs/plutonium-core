# frozen_string_literal: true

module Plutonium
  module StructuredInputs
    # Rewrites structured-input params in place through ParamCleaner. Shared by
    # the resource controller and the interactive-actions controller.
    module ParamsConcern
      # @param definition a definition instance (resource) or class (interaction)
      #   exposing `defined_structured_inputs`
      # @param params [Hash] extracted form params (mutable copy)
      # @return [Hash]
      def clean_structured_inputs(definition, params)
        registry = structured_inputs_registry(definition)
        return params unless registry

        registry.each do |name, entry|
          next unless params.key?(name)

          repeat = entry[:options]&.fetch(:repeat, false)
          params[name] = Plutonium::StructuredInputs::ParamCleaner.call(params[name], repeat:)
        end
        params
      end

      private

      def structured_inputs_registry(definition)
        if definition.respond_to?(:defined_structured_inputs)
          definition.defined_structured_inputs
        elsif definition.class.respond_to?(:defined_structured_inputs)
          definition.class.defined_structured_inputs
        end
      end
    end
  end
end
