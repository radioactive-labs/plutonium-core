module Plutonium
  module Query
    class Base
      include Plutonium::Definition::DefineableProps
      include Plutonium::Definition::ConfigAttr
      include Plutonium::Definition::Presentable

      defineable_props :field, :input

      # Applies the query to the given scope using the provided parameters.
      #
      # @param scope [Object] The initial scope to which the query will be applied.
      # @param params [Hash] The parameters for the query.
      # @return [Object] The modified scope.
      def apply(scope, params)
        if defined_inputs.size == params.size
          apply_internal(scope, params)
        else
          scope
        end
      end

      private

      # Abstract method to apply the query logic to the scope.
      # Should be implemented by subclasses.
      #
      # @param scope [Object] The initial scope.
      # @param params [Hash] The parameters for the query.
      # @raise [NotImplementedError] If the method is not implemented.
      def apply_internal(scope, params)
        raise NotImplementedError, "#{self.class}#apply_internal(scope, params)"
      end
    end
  end
end
