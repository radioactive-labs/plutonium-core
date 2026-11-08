# frozen_string_literal: true

module Plutonium
  module Rbac
    class RoleAssignment < ActiveRecord::Base
      self.table_name = "plutonium_rbac_role_assignments"

      # The escalation guard runs on create only, so an assignment's role and
      # holder never change afterwards: re-pointing a row would hand a role out
      # unchecked. A validation, not attr_readonly: with
      # raise_on_assign_to_attr_readonly on, Rails raises when loading an
      # association rewrites the (unchanged) foreign key on its inverse, and
      # with it off the change is silently dropped. Invite transfer moves rows
      # with update_all, which skips validations on purpose.
      IDENTITY_ATTRIBUTES = %i[role_id holder_type holder_id].freeze

      belongs_to :holder, polymorphic: true
      belongs_to :role, class_name: "Plutonium::Rbac::Role"

      validates :role_id, uniqueness: {scope: %i[holder_type holder_id]}
      validate :role_in_holder_tenant
      validate :actor_may_grant_role, on: :create
      validate :identity_unchanged, on: :update

      after_commit { Current.invalidate! }

      private

      def role_in_holder_tenant
        return unless role&.entity

        errors.add(:role, :rbac_wrong_tenant) unless role.entity == holder.rbac_entity
      end

      def actor_may_grant_role
        return unless role

        denied = Rbac.ungrantable_keys(role.permissions)
        errors.add(:role, :rbac_not_grantable, keys: denied.join(", ")) if denied.any?
      end

      def identity_unchanged
        IDENTITY_ATTRIBUTES.each { |name| errors.add(name, :rbac_readonly) if attribute_changed?(name) }
      end
    end
  end
end
