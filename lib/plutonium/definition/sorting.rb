module Plutonium
  module Definition
    module Sorting
      extend ActiveSupport::Concern

      # The framework-wide default sort: newest first. Named rather than
      # inlined so a caller can tell "nobody has chosen a sort" apart from
      # "someone chose exactly this" — see Definition::Positioning, which only
      # claims default_sort while it is still untouched.
      DEFAULT_SORT = [:id, :desc].freeze

      included do
        defineable_props :sort

        class_attribute :_default_sort, instance_writer: false, instance_predicate: false

        def self.sorts(*names)
          names.each { |name| sort name }
        end

        def self.default_sort(field = nil, direction = :asc, &block)
          self._default_sort = if block_given?
            block
          elsif field
            [field, direction]
          end
          _default_sort
        end

        # Set a sensible default: newest items first
        default_sort(*DEFAULT_SORT)
      end

      def default_sort
        self.class._default_sort
      end
    end
  end
end
