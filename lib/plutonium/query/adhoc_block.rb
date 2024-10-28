module Plutonium
  module Query
    class AdhocBlock < Base
      attr_reader :body

      # Initializes a AdhocBlock with a given block of code.
      #
      # @param body [Proc] The block of code for the query.
      def initialize(body)
        super()
        @body = body
      end

      def apply(scope, **)
        body.call(scope, **)
      end
    end
  end
end
