module Plutonium
  module Query
    module Filters
      # Select filter for choosing from a predefined collection of options
      #
      # @example Basic usage with array
      #   filter :status, with: :select, choices: %w[draft published archived]
      #
      # @example With proc for dynamic choices
      #   filter :category, with: :select, choices: -> { Category.pluck(:name, :id) }
      #
      # @example With multiple selection
      #   filter :tags, with: :select, choices: %w[ruby rails js], multiple: true
      #
      class Select < Filter
        def initialize(choices: nil, multiple: false, **)
          super(**)
          @choices = choices
          @multiple = multiple
        end

        def apply(scope, value:)
          return scope if value.blank?

          if @multiple && value.is_a?(Array)
            scope.where(key => value.reject(&:blank?))
          else
            scope.where(key => value)
          end
        end

        def customize_inputs
          input :value,
            as: :select,
            choices: resolved_choices,
            multiple: @multiple,
            include_blank: @multiple ? false : "All"
        end

        private

        def resolved_choices
          case @choices
          when Proc
            @choices
          when nil
            []
          else
            @choices
          end
        end
      end
    end
  end
end
