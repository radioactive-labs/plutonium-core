module Plutonium
  module Reactor
    class ResourcePolicy
      include Plutonium::Policy::Initializer

      class Scope < Plutonium::Policy::Scope
      end

      # Core actions

      def create?
        true
      end

      def read?
        true
      end

      def update?
        true
      end

      def destroy?
        true
      end

      # Inferred actions

      def index?
        read?
      end

      def show?
        read?
      end

      def new?
        create?
      end

      def edit?
        update?
      end

      # Core attributes

      def permitted_attributes_for_create
        autodetect_fields_for :permitted_attributes_for_create
      end

      def permitted_attributes_for_read
        autodetect_fields_for :permitted_attributes_for_read
      end

      def permitted_attributes_for_update
        permitted_attributes_for_create
      end

      # Inferred attributes

      def permitted_attributes_for_index
        permitted_attributes_for_read
      end

      def permitted_attributes_for_show
        permitted_attributes_for_read
      end

      def permitted_attributes_for_new
        permitted_attributes_for_create
      end

      def permitted_attributes_for_edit
        permitted_attributes_for_update
      end

      def permitted_associations
        []
      end

      private

      def autodetect_fields_for(method_name)
        maybe_warn_autodetect_usage method_name

        context.resource_class.resource_fields
      end

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
