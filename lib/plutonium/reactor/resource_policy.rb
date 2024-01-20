module Plutonium
  module Reactor
    class ResourcePolicy
      include Plutonium::Policy::Initializer

      class Scope < Plutonium::Policy::Scope
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
        maybe_warn_autodetect_usage :permitted_attributes_for_read
        context.resource_class.columns.map { |col| col.name.to_sym } - %i[id]
      end

      def permitted_attributes_for_new
        permitted_attributes_for_create
      end

      def permitted_attributes_for_create
        maybe_warn_autodetect_usage :permitted_attributes_for_create
        context.resource_class.columns.map { |col| col.name.to_sym } - %i[id created_at updated_at]
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

      private

      def maybe_warn_autodetect_usage(method)
        return if Rails.env.local?

        Rails.logger.warn %(
          🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨

          Resource field auto-detection violation #{self.class}##{method}

          Using auto-detected resource fields in production is not recommended.
          It can lead to accidental exposure of sensitive resource fields.

          Override a #{context.resource_class}Policy with your own ##{method} method.

          🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨
        )
      end
    end
  end
end
