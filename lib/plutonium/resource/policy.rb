module Plutonium
  module Resource
    # Policy class to define permissions and attributes for a resource
    class Policy
      include Plutonium::Policy::Initializer

      class Scope < Plutonium::Policy::Scope
      end

      # Sends a method and raises an error if the method is not implemented
      # @param [Symbol] method The method to send
      def send_with_report(method)
        unless respond_to?(method)
          raise NotImplementedError, "#{self.class.name} does not implement the required #{method}"
        end

        send(method)
      end

      # Core actions

      # Checks if the create action is permitted
      # @return [Boolean]
      def create?
        false
      end

      # Checks if the read action is permitted
      # @return [Boolean]
      def read?
        false
      end

      # Checks if the update action is permitted
      # @return [Boolean]
      def update?
        create?
      end

      # Checks if the destroy action is permitted
      # @return [Boolean]
      def destroy?
        create?
      end

      # Inferred actions

      # Checks if the index action is permitted
      # @return [Boolean]
      def index?
        read?
      end

      # Checks if the new action is permitted
      # @return [Boolean]
      def new?
        create?
      end

      # Checks if the show action is permitted
      # @return [Boolean]
      def show?
        read?
      end

      # Checks if the edit action is permitted
      # @return [Boolean]
      def edit?
        update?
      end

      # Checks if the search action is permitted
      # @return [Boolean]
      def search?
        index?
      end

      # Core attributes

      # Returns the permitted attributes for the create action
      # @return [Array<Symbol>]
      def permitted_attributes_for_create
        autodetect_permitted_fields(:permitted_attributes_for_create) - [
          context.resource_context.resource_class.primary_key.to_sym, # primary_key
          :created_at, :updated_at # timestamps
        ]
      end

      # Returns the permitted attributes for the read action
      # @return [Array<Symbol>]
      def permitted_attributes_for_read
        autodetect_permitted_fields(:permitted_attributes_for_read)
      end

      # Returns the permitted attributes for the update action
      # @return [Array<Symbol>]
      def permitted_attributes_for_update
        permitted_attributes_for_create
      end

      # Inferred attributes

      # Returns the permitted attributes for the index action
      # @return [Array<Symbol>]
      def permitted_attributes_for_index
        permitted_attributes_for_read
      end

      # Returns the permitted attributes for the show action
      # @return [Array<Symbol>]
      def permitted_attributes_for_show
        permitted_attributes_for_read
      end

      # Returns the permitted attributes for the new action
      # @return [Array<Symbol>]
      def permitted_attributes_for_new
        permitted_attributes_for_create
      end

      # Returns the permitted attributes for the edit action
      # @return [Array<Symbol>]
      def permitted_attributes_for_edit
        permitted_attributes_for_update
      end

      # # Returns the permitted associations
      # # @return [Array<Symbol>]
      # def permitted_associations
      #   []
      # end

      private

      # Autodetects the permitted fields for a given method
      # @param [Symbol] method_name The name of the method
      # @return [Array<Symbol>]
      def autodetect_permitted_fields(method_name)
        warn_about_autodetect_usage(method_name)

        context.resource_context.resource_class.resource_field_names
      end

      # Warns about the usage of auto-detection of fields
      # @param [Symbol] method The method name
      # @raise [RuntimeError] if not in development environment
      def warn_about_autodetect_usage(method)
        unless Rails.env.development?
          raise "Resource field auto-detection: #{self.class}##{method} outside development"
        end

        Plutonium.logger.warn %(
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
