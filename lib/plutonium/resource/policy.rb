# frozen_string_literal: true

module Plutonium
  module Resource
    # Policy class to define permissions and attributes for a resource.
    # This class provides methods to check permissions for various actions
    # and to retrieve permitted attributes for these actions.
    class Policy < ::ActionPolicy::Base
      authorize :user, allow_nil: false
      authorize :entity_scope, allow_nil: true
      authorize :parent, optional: true
      authorize :parent_association, optional: true

      relation_scope do |relation|
        default_relation_scope(relation)
      end

      # Wraps apply_scope to verify default_relation_scope was called.
      # This prevents accidental multi-tenancy leaks when overriding relation_scope.
      def apply_scope(relation, type:, **options)
        @_default_relation_scope_applied = false
        result = super
        verify_default_relation_scope_applied! if type == :active_record_relation
        result
      end

      # Explicitly skip the default relation scope verification.
      #
      # Call this when you intentionally want to bypass parent/entity scoping.
      # This should be rare - consider using a separate portal instead.
      #
      # @example Skipping default scoping (use sparingly)
      #   relation_scope do |relation|
      #     skip_default_relation_scope!
      #     relation.where(featured: true)  # No parent/entity scoping
      #   end
      def skip_default_relation_scope!
        @_default_relation_scope_applied = true
      end

      # Applies Plutonium's default scoping (parent or entity) to a relation.
      #
      # This method MUST be called in any custom relation_scope to ensure proper
      # parent/entity scoping. Failure to call it will raise an error.
      #
      # @example Overriding inherited scope while keeping default scoping
      #   # Parent policy has custom filtering you want to replace
      #   class AdminPostPolicy < PostPolicy
      #     relation_scope do |relation|
      #       # Replace inherited scope but keep Plutonium's parent/entity scoping
      #       default_relation_scope(relation)
      #     end
      #   end
      #
      # @example Adding filtering on top of default scoping
      #   relation_scope do |relation|
      #     default_relation_scope(relation).where(published: true)
      #   end
      #
      # @param relation [ActiveRecord::Relation] The relation to scope
      # @return [ActiveRecord::Relation] The scoped relation
      def default_relation_scope(relation)
        @_default_relation_scope_applied = true

        if parent || parent_association
          unless parent && parent_association
            raise ArgumentError, "parent and parent_association must both be provided together"
          end

          # Parent association scoping (nested routes)
          # The parent was already entity-scoped during authorization, so children
          # accessed through the parent don't need additional entity scoping
          assoc_reflection = parent.class.reflect_on_association(parent_association)
          if assoc_reflection.collection?
            # has_many: merge with the association's scope
            parent.public_send(parent_association).merge(relation)
          else
            # has_one: scope by foreign key
            relation.where(assoc_reflection.foreign_key => parent.id)
          end
        elsif entity_scope
          # Entity scoping (multi-tenancy)
          relation.associated_with(entity_scope)
        else
          relation
        end
      end

      # Sends a method and raises an error if the method is not implemented.
      #
      # @param method [Symbol] The method to send.
      def send_with_report(method)
        unless respond_to?(method)
          raise NotImplementedError, "#{self.class.name} does not implement the required #{method}"
        end

        public_send(method)
      end

      # Core actions

      # Checks if the create action is permitted.
      #
      # @return [Boolean] false by default.
      def create?
        false
      end

      # Checks if the read action is permitted.
      #
      # @return [Boolean] false by default.
      def read?
        false
      end

      # Checks if the update action is permitted.
      #
      # @return [Boolean] Delegates to create?.
      def update?
        create?
      end

      # Checks if the destroy action is permitted.
      #
      # @return [Boolean] Delegates to create?.
      def destroy?
        create?
      end

      # Inferred actions

      # Checks if the index action is permitted.
      #
      # @return [Boolean] Delegates to read?.
      def index?
        read?
      end

      # Checks if the new action is permitted.
      #
      # @return [Boolean] Delegates to create?.
      def new?
        create?
      end

      # Checks if the show action is permitted.
      #
      # @return [Boolean] Delegates to read?.
      def show?
        read?
      end

      # Checks if the edit action is permitted.
      #
      # @return [Boolean] Delegates to update?.
      def edit?
        update?
      end

      # Checks if record search is permitted.
      #
      # @return [Boolean] Delegates to index?.
      def search?
        index?
      end

      # Core attributes

      # Returns the permitted attributes for the create action.
      #
      # @return [Array<Symbol>] The permitted attributes.
      def permitted_attributes_for_create
        autodetect_permitted_fields(:permitted_attributes_for_create) - [
          resource_class.primary_key.to_sym, # primary_key
          :created_at, :updated_at # timestamps
        ]
      end

      # Returns the permitted attributes for the read action.
      #
      # @return [Array<Symbol>] The permitted attributes.
      def permitted_attributes_for_read
        autodetect_permitted_fields(:permitted_attributes_for_read)
      end

      # Returns the permitted attributes for the update action.
      #
      # @return [Array<Symbol>] Delegates to permitted_attributes_for_create.
      def permitted_attributes_for_update
        permitted_attributes_for_create
      end

      # Inferred attributes

      # Returns the permitted attributes for the index action.
      #
      # @return [Array<Symbol>] Delegates to permitted_attributes_for_read.
      def permitted_attributes_for_index
        permitted_attributes_for_read
      end

      # Returns the permitted attributes for the show action.
      #
      # @return [Array<Symbol>] Delegates to permitted_attributes_for_read.
      def permitted_attributes_for_show
        permitted_attributes_for_read
      end

      # Returns the permitted attributes for the new action.
      #
      # @return [Array<Symbol>] Delegates to permitted_attributes_for_create.
      def permitted_attributes_for_new
        permitted_attributes_for_create
      end

      # Returns the permitted attributes for the edit action.
      #
      # @return [Array<Symbol>] Delegates to permitted_attributes_for_update.
      def permitted_attributes_for_edit
        permitted_attributes_for_update
      end

      # Returns the permitted associations.
      #
      # @return [Array<Symbol>] An empty array by default.
      def permitted_associations
        []
      end

      private

      def resource_class
        record.instance_of?(Class) ? record : record.class
      end

      # Verifies that default_relation_scope was called during scope application.
      # Raises an error if it wasn't, preventing accidental multi-tenancy leaks.
      def verify_default_relation_scope_applied!
        return if @_default_relation_scope_applied

        raise <<~MSG.squish
          #{self.class.name} did not call `default_relation_scope` in its relation_scope.
          This can cause multi-tenancy leaks. Either call `default_relation_scope(relation)`
          or `super(relation)` in your relation_scope block.
        MSG
      end

      # Autodetects the permitted fields for a given method.
      #
      # @param method_name [Symbol] The name of the method.
      # @return [Array<Symbol>] The auto-detected permitted fields.
      def autodetect_permitted_fields(method_name)
        warn_about_autodetect_usage(method_name)
        resource_class.resource_field_names
      end

      # Warns about the usage of auto-detection of fields.
      #
      # @param method [Symbol] The method name.
      # @raise [RuntimeError] if not in the development environment.
      def warn_about_autodetect_usage(method)
        unless Rails.env.development?
          raise "Resource field auto-detection: #{self.class}##{method} outside development"
        end

        Plutonium.logger.warn {
          %(
            🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨

            Resource field auto-detection: #{self.class}##{method}

            Auto-detected resource fields result in security holes and will fail outside of development.
            Override #{resource_class}Policy or #{self.class} with your own ##{method} method.

            🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨
          )
        }
      end
    end
  end
end
