module Plutonium
  module Definition
    module Sorting
      extend ActiveSupport::Concern

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
        default_sort :id, :desc
      end

      def default_sort
        self.class._default_sort
      end
    end
  end
end
