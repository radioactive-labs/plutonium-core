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
      end

      def apply(scope, context: nil, **)
        scope.public_send(name, **)
      end
    end
  end
end
