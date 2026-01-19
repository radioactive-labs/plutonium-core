module Plutonium
  module Query
    module Filters
      # Date filter for date/datetime columns
      #
      # @example Filter by exact date
      #   filter :created_at, with: :date, predicate: :eq
      #
      # @example Filter by date before
      #   filter :due_date, with: :date, predicate: :lt
      #
      # @example Filter by date on or after
      #   filter :start_date, with: :date, predicate: :gteq
      #
      class Date < Filter
        VALID_PREDICATES = [
          :eq,    # Equal (on this date)
          :not_eq, # Not equal
          :lt,    # Less than (before)
          :lteq,  # Less than or equal (on or before)
          :gt,    # Greater than (after)
          :gteq   # Greater than or equal (on or after)
        ].freeze

        def initialize(predicate: :eq, **)
          super(**)
          unless VALID_PREDICATES.include?(predicate)
            raise ArgumentError, "unsupported predicate #{predicate}. Valid predicates are: #{VALID_PREDICATES.join(", ")}"
          end
          @predicate = predicate
        end

        def apply(scope, value:)
          return scope if value.blank?

          date_value = parse_date(value)
          return scope unless date_value

          case @predicate
          when :eq
            scope.where(key => date_value.all_day)
          when :not_eq
            scope.where.not(key => date_value.all_day)
          when :lt
            scope.where(key => ...date_value.beginning_of_day)
          when :lteq
            scope.where(key => ..date_value.end_of_day)
          when :gt
            scope.where(key => (date_value.end_of_day + 1.second)..)
          when :gteq
            scope.where(key => date_value.beginning_of_day..)
          else
            raise NotImplementedError, "date filter predicate #{@predicate}"
          end
        end

        def customize_inputs
          input :value, as: :date
          field :value, placeholder: generate_placeholder
        end

        private

        def parse_date(value)
          case value
          when ::Date, ::DateTime, ::Time, ActiveSupport::TimeWithZone
            value.to_date
          when String
            ::Date.parse(value)
          end
        rescue ArgumentError
          nil
        end

        def generate_placeholder
          base = key.to_s.humanize
          case @predicate
          when :eq
            base
          when :not_eq
            "#{base} not on..."
          when :lt
            "#{base} before..."
          when :lteq
            "#{base} on or before..."
          when :gt
            "#{base} after..."
          when :gteq
            "#{base} on or after..."
          else
            base
          end
        end
      end
    end
  end
end
