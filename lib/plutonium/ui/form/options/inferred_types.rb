# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Options
        module InferredTypes
          private

          def infer_field_component
            case inferred_field_type
            when :rich_text
              return :markdown
            end

            inferred_field_component = super
            case inferred_field_component
            when :select
              :slim_select
            when :date, :time, :datetime
              :flatpickr
            else
              inferred_field_component
            end
          end
        end
      end
    end
  end
end
