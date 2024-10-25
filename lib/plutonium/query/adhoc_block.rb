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

      private

      # Applies the block query to the given scope.
      #
      # @param scope [Object] The initial scope.
      # @param params [Hash] The parameters for the query.
      # @return [Object] The modified scope.
      def apply_internal(scope, params)
        if body.arity == 1
          body.call(scope)
        else
          body.call(scope, **params)
        end
      end
    end
  end
end
