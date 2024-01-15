module Plutonium
  module Core
    class ResourceContextScope
      attr_reader :attribute, :record

      def initialize(record, attribute: :entity)
        @record = record
        @attribute = attribute
      end
    end
  end
end
