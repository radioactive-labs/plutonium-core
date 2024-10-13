module Plutonium
  module Query
    class ModelScope < Base
      attr_reader :name

      # Initializes a ModelScope with a given name.
      #
      # @param name [Symbol] The name of the scope.
      def initialize(name)
        super()

        @name = name
        yield self if block_given?
      end

      private

      # Chains the the scope onto the given scope.
      #
      # @param scope [Object] The initial scope.
      # @param params [Hash] The parameters for the query.
      # @return [Object] The modified scope.
      def apply_internal(scope, params)
        scope.public_send(name, **params)
      end
    end
  end
end
