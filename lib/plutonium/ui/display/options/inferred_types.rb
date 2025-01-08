# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Options
        module InferredTypes
          private

          def infer_field_component
            case inferred_field_type
            when :attachment
              :attachment
            else
              super
            end
          end
        end
      end
    end
  end
end
