require "action_controller"

module Plutonium
  module Refinements
    module ParameterRefinements
      refine ActionController::Parameters do
        def nilify
          transform_values { |value| nilify_internal value }
        end

        private

        def nilify_internal(value)
          case value
          when String
            value.presence
          when Hash
            nilify value
          when Array
            value.map { |val| nilify_internal val }.compact
          else
            value
          end
        end
      end
    end
  end
end
