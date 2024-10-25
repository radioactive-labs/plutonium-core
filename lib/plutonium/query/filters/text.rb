module Plutonium
  module Query
    module Filters
      class Text < Filter
        def initialize(predicate: :eq, **)
          super(**)
          @predicate = predicate
        end

        def apply(scope, params)
          case @predicate
          when :eq
            scope.where(key => params[:query])
          else
            raise ArgumentError, "unsupported predicate #{@predicate}"
          end
        end

        def customize_inputs
          input :query
          field :query, placeholder: key.to_s.humanize
        end
      end
    end
  end
end
