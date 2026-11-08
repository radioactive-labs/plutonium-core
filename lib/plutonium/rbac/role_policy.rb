# frozen_string_literal: true

module Plutonium
  module Rbac
    # Authorization for role records. Managing roles is itself RBAC-gated
    # (rbac_role.read, .create, ...), so a system Owner role with "*" covers it
    # and nothing special-cases admins.
    #
    # Named +RolePolicy+ so ActionPolicy's "#{record_class}Policy" inference
    # finds it. Portals override with MyPortal::Plutonium::Rbac::RolePolicy.
    class RolePolicy < Plutonium::Resource::Policy
      include Plutonium::Rbac::Policy

      # Default scoping would hide global roles (they have no entity), so it is
      # skipped on purpose and the tenant filter is written out here: global
      # roles plus the current tenant's, never another tenant's.
      relation_scope do |relation|
        skip_default_relation_scope!
        global = relation.where(entity_type: nil, entity_id: nil)
        entity_scope ? global.or(relation.where(entity: entity_scope)) : global
      end

      # On collection routes (new, index) the record is the class; on a built
      # record it must belong to the current tenant (nil outside one).
      def create? = super && (record.instance_of?(Class) || record.entity == entity_scope)

      def update? = super && editable_here?

      def destroy? = super && editable_here?

      def permitted_attributes_for_create = %i[name key description permissions]

      def permitted_attributes_for_read = %i[name key description permissions system_role created_at]

      # The grouped permission list is too tall for a table cell.
      def permitted_attributes_for_index = permitted_attributes_for_read - %i[permissions]

      private

      # System roles belong to code (plutonium:rbac:sync); a tenant cannot edit
      # global roles, and an unscoped portal cannot edit a tenant's.
      def editable_here? = !record.system_role? && record.entity == entity_scope
    end
  end
end
