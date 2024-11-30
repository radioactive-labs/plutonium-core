# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Options
        module InferredTypes
          private

          def infer_field_component
            return :markdown if inferred_field_type == :rich_text

            component = super
            case component
            when :select
              :slim_select
            else
              component
            end
          end
        end
      end
    end
  end
end
