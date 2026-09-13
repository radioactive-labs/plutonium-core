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
        def initialize(true_label: nil, false_label: nil, **)
          super(**)
          @true_label = true_label || Plutonium::Translation.t("plutonium.boolean.true")
          @false_label = false_label || Plutonium::Translation.t("plutonium.boolean.false")
        end

        def humanize_value(value)
          return "" if value.blank?
          ActiveModel::Type::Boolean.new.cast(value) ? @true_label : @false_label
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
            include_blank: Plutonium::Translation.t("plutonium.query.all")
        end
      end
    end
  end
end
