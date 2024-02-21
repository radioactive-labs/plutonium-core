module Plutonium
  module Reactor
    class ResourcePolicy
      include Plutonium::Policy::Initializer

      class Scope < Plutonium::Policy::Scope
      end

      # Core actions

      def create?
        false
      end

      def read?
        false
      end

      def update?
        create?
      end

      def destroy?
        create?
      end

      # Inferred actions

      def index?
        read?
      end

      def new?
        create?
      end

      def show?
        read?
      end

      def edit?
        update?
      end

      # Core attributes

      def permitted_attributes_for_create
        autodetect_fields_for(:permitted_attributes_for_create) - [context.resource_context.resource_class.primary_key.to_sym, :created_at, :updated_at]
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

      # def permitted_associations
      #   []
      # end

      private

      def autodetect_fields_for(method_name)
        maybe_warn_autodetect_usage method_name

        context.resource_context.resource_class.resource_field_names
      end

      def maybe_warn_autodetect_usage(method)
        raise "Resource field auto-detection: #{self.class}##{method} outside development" unless Rails.env.development?

        Rails.logger.warn %(
          🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨

          Resource field auto-detection: #{self.class}##{method}

          Auto-detected resource fields result in security holes and will fail outside of development.
          Override #{context.resource_context.resource_class}Policy or #{self.class} with your own ##{method} method.

          🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨
        )
      end
    end
  end
end
