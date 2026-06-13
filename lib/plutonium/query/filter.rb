module Plutonium
  module Query
    class Filter < Base
      attr_reader :key

      class << self
        # Lookup a filter class by type symbol or return the class if already a Filter
        # @param type [Symbol, Class] The type symbol (e.g., :text, :select) or a Filter class
        # @return [Class] The filter class
        def lookup(type)
          return type if type.is_a?(Class) && type < Filter

          class_name = "Plutonium::Query::Filters::#{type.to_s.classify}"
          class_name.constantize
        rescue NameError
          raise ArgumentError, "Unknown filter type: #{type}. Expected #{class_name} to exist."
        end
      end

      attr_reader :resource_class

      def initialize(key:, resource_class: nil)
        super()
        @key = key
        @resource_class = resource_class
      end
    end
  end
end
