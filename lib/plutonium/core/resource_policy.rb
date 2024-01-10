module Plutonium
  module Core
    module ResourcePolicy
      def self.included(base)
        base.include Plutonium::Policy::Initializer
      end

      def read?
        true
      end

      def index?
        read?
      end

      def show?
        read?
      end

      def create?
        true
      end

      def new?
        create?
      end

      def update?
        edit?
      end

      def edit?
        true
      end

      def destroy?
        true
      end

      def permitted_attributes_for_index
        permitted_attributes_for_read
      end

      def permitted_attributes_for_show
        permitted_attributes_for_read
      end

      def permitted_attributes_for_read
        raise NotImplementedError, "permitted_attributes_for_read"
      end

      def permitted_attributes_for_new
        permitted_attributes_for_create
      end

      def permitted_attributes_for_create
        raise NotImplementedError, "permitted_attributes_for_create"
      end

      def permitted_attributes_for_edit
        permitted_attributes_for_update
      end

      def permitted_attributes_for_update
        permitted_attributes_for_create
      end

      def permitted_associations
        []
      end

      def begin_resource_action?
        true
      end

      def commit_resource_action?
        true
      end
    end
  end
end
