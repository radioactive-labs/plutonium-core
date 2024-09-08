module Plutonium
  module Definition
    module Search
      extend ActiveSupport::Concern

      included do
        class_attribute :_search_definition, instance_accessor: false, instance_predicate: false
      end

      def search_definition
        self.class._search_definition
      end

      class_methods do
        def search(&block)
          self._search_definition = block
        end
      end
    end
  end
end
