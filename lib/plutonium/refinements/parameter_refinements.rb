module Plutonium
  module Refinements
    module ParameterRefinements
      refine ActionController::Parameters do
        def nilify
          transform_values do |value|
            case value
            when String
              value.presence
            when Hash
              nilify value
            when Array
              value.compact_blank
            else
              value
            end
          end
        end
      end
    end
  end
end
