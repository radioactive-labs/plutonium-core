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

      def initialize(key:)
        super()
        @key = key
      end

      # Human-readable rendering of a single filter value for the active
      # filter pills. Default falls through to `value.to_s`. Subclasses
      # override to translate raw param values (e.g. an association id or
      # a boolean string) into something the user can recognise.
      def humanize_value(value)
        value.to_s
      end
    end
  end
end
