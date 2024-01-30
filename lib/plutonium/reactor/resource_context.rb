module Plutonium
  module Reactor
    class ResourceContext
      attr_reader :user, :resource_record, :resource_class, :parent, :scope

      def initialize(user:, resource_record:, resource_class:, parent: nil, scope: nil)
        @user = user
        @resource_record = resource_record
        @resource_class = resource_class || resource_record&.class
        @parent = parent
        @scope = scope
      end
    end
  end
end
