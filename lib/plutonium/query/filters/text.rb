module Plutonium
  module Query
    module Filters
      class Text < Filter
        VALID_PREDICATES = [
          :eq,           # Equal
          :not_eq,       # Not equal
          :matches,      # LIKE with wildcards
          :not_matches,  # NOT LIKE with wildcards
          :starts_with,  # LIKE with suffix wildcard
          :ends_with,    # LIKE with prefix wildcard
          :contains,     # LIKE with wildcards on both sides
          :not_contains # NOT LIKE with wildcards on both sides
        ].freeze

        def initialize(predicate: :eq, **)
          super(**)
          unless VALID_PREDICATES.include?(predicate)
            raise ArgumentError, "unsupported predicate #{predicate}. Valid predicates are: #{VALID_PREDICATES.join(", ")}"
          end
          @predicate = predicate
        end

        def apply(scope, query:)
          case @predicate
          when :eq
            scope.where(key => query)
          when :not_eq
            scope.where.not(key => query)
          when :matches
            scope.where("#{key} LIKE ?", query.tr("*", "%"))
          when :not_matches
            scope.where.not("#{key} LIKE ?", query.tr("*", "%"))
          when :starts_with
            scope.where("#{key} LIKE ?", "#{sanitize_like(query)}%")
          when :ends_with
            scope.where("#{key} LIKE ?", "%#{sanitize_like(query)}")
          when :contains
            scope.where("#{key} LIKE ?", "%#{sanitize_like(query)}%")
          when :not_contains
            scope.where.not("#{key} LIKE ?", "%#{sanitize_like(query)}%")
          else
            raise NotImplementedError, "text filter predicate #{@predicate}"
          end
        end

        def customize_inputs
          input :query
          field :query, placeholder: generate_placeholder
        end

        private

        def generate_placeholder
          base = key.to_s.humanize
          case @predicate
          when :matches, :not_matches
            "#{base} (use * as wildcard)"
          when :starts_with
            "#{base} starts with..."
          when :ends_with
            "#{base} ends with..."
          when :contains, :not_contains
            "#{base} contains..."
          else
            base
          end
        end

        def sanitize_like(string)
          # Escape special LIKE characters: %, _, and \
          string.gsub(/[%_\\]/) { |char| "\\#{char}" }
        end
      end
    end
  end
end
