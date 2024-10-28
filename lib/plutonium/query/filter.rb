module Plutonium
  module Query
    class Filter < Base
      attr_reader :key

      def initialize(key:)
        super()
        @key = key
      end
    end
  end
end
