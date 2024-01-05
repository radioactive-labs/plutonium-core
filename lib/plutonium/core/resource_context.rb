module Plutonium
  module Core
    class ResourceContext
      attr_reader :resource_class, :user, :parent

      def initialize(resource_class:, user:, parent: nil)
        @resource_class = resource_class
        @user = user
        @parent = parent
      end
    end
  end
end
