module Plutonium
  module Definition
    module Sorting
      extend ActiveSupport::Concern

      # The framework-wide default sort: newest first.
      #
      # A SENTINEL, compared with `equal?` — see Definition::Positioning, which
      # only claims default_sort while nobody has chosen one. `==` cannot answer
      # that question: `default_sort :id, :desc` builds a fresh `[field,
      # direction]` array that is value-equal to this one, so an app that
      # explicitly asked for newest-first would have its choice silently
      # overwritten. Identity distinguishes them, which is why the installation
      # below assigns this exact object rather than going through `default_sort`.
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

        # Set a sensible default: newest items first. Assigned directly rather
        # than through `default_sort` so `_default_sort` holds the SENTINEL
        # object itself — that identity is what tells a later `position_on` the
        # sort is still untouched. Equivalent otherwise: `default_sort :id,
        # :desc` would store a value-equal `[:id, :desc]`.
        self._default_sort = DEFAULT_SORT
      end

      def default_sort
        self.class._default_sort
      end
    end
  end
end
