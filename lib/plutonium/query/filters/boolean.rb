module Plutonium
  module Query
    module Filters
      # Boolean filter for true/false columns
      #
      # @example Basic usage
      #   filter :active, with: :boolean
      #
      # @example With custom labels
      #   filter :published, with: :boolean, true_label: "Published", false_label: "Draft"
      #
      class Boolean < Filter
        def initialize(true_label: "Yes", false_label: "No", **)
          super(**)
          @true_label = true_label
          @false_label = false_label
        end

        def apply(scope, value:)
          return scope if value.blank?

          bool_value = ActiveModel::Type::Boolean.new.cast(value)
          scope.where(key => bool_value)
        end

        def customize_inputs
          input :value,
            as: :select,
            choices: [[@true_label, "true"], [@false_label, "false"]],
            include_blank: "All"
        end
      end
    end
  end
end
