module Plutonium
  module Query
    module Filters
      # Filter by a no_fly_list `has_tags` context, through the gem's own
      # query scopes.
      #
      # @example Records with any of the chosen tags
      #   filter :labels, with: :tags
      #
      # @example Records with every chosen tag
      #   filter :labels, with: :tags, match: :all
      #
      class Tags < Filter
        def initialize(match: :any, **)
          super(**)
          @match = match
        end

        def apply(scope, value:)
          tags = Array(value).compact_blank
          return scope if tags.empty?

          scope.public_send(:"with_#{@match}_#{key}", tags)
        end

        def humanize_value(value)
          Array(value).compact_blank.join(", ")
        end

        def customize_inputs
          input :value, as: Plutonium::UI::Form::Components::TagsFilter, context: key
        end
      end
    end
  end
end
