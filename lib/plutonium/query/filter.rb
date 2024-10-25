module Plutonium
  module Query
    class Filter < Base
      attr_reader :key

      def initialize(key:)
        super()
        @key = key
      end

      def apply(scope, params)
        raise NotImplementedError, "#{self.class}#apply(scope, params)"
      end
    end
  end
end
