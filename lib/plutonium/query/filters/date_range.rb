module Plutonium
  module Query
    module Filters
      # DateRange filter for filtering between two dates
      #
      # @example Basic usage
      #   filter :created_at, with: :date_range
      #
      # @example With custom labels
      #   filter :published_at, with: :date_range, from_label: "Published from", to_label: "Published to"
      #
      class DateRange < Filter
        def initialize(from_label: nil, to_label: nil, **)
          super(**)
          @from_label = from_label
          @to_label = to_label
        end

        def apply(scope, from: nil, to: nil)
          from_date = parse_date(from)
          to_date = parse_date(to)

          if from_date && to_date
            scope.where(key => from_date.beginning_of_day..to_date.end_of_day)
          elsif from_date
            scope.where(key => from_date.beginning_of_day..)
          elsif to_date
            scope.where(key => ..to_date.end_of_day)
          else
            scope
          end
        end

        def customize_inputs
          input :from, as: :date
          input :to, as: :date
          field :from, placeholder: @from_label || "#{key.to_s.humanize} from..."
          field :to, placeholder: @to_label || "#{key.to_s.humanize} to..."
        end

        private

        def parse_date(value)
          return nil if value.blank?

          case value
          when ::Date, ::DateTime, ::Time, ActiveSupport::TimeWithZone
            value.to_date
          when String
            ::Date.parse(value)
          end
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
