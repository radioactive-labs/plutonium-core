module Plutonium
  module Core
    class ResourceContext
      attr_reader :resource_class, :user, :parent, :scope

      def initialize(resource_class:, user:, parent: nil, scope: nil)
        @resource_class = resource_class
        @user = user
        @parent = parent
        @scope = scope
      end
    end
  end
end
