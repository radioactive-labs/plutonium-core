module Plutonium
  module Query
    class Base
      include Plutonium::Definition::DefineableProps
      include Plutonium::Definition::ConfigAttr
      include Plutonium::Definition::Presentable

      defineable_props :field, :input

      # Applies a parameterized query to modify the given scope.
      #
      # @param scope [Object] The initial scope that will be filtered, sorted, or otherwise modified
      #   by applying this query. This is typically an ActiveRecord::Relation or similar query object.
      #
      # @param params [Hash] Optional parameters that configure how the query is applied.
      #   The specific parameters accepted depend on the implementing class.
      #
      # @return [Object] The modified scope with this query's conditions applied. Returns the same
      #   type as the input scope parameter.
      #
      # @example Basic usage
      #   query.apply(User.all, status: 'active')
      #
      def apply(scope, **params)
        raise NotImplementedError, "#{self.class}#apply(scope, **params)"
      end
    end
  end
end
