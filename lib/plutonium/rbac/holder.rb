# frozen_string_literal: true

module Plutonium
  module Rbac
    # Include in any model that holds roles (a membership, a user, an admin,
    # a pending invite).
    #
    # `rbac_role_ids=` and `rbac_roles=` stage the change rather than writing
    # through the has_many: Rails' generated writers save immediately on a
    # persisted record, outside the holder's save, so a rejected assignment
    # would raise mid-assign_attributes. Staged ids validate with the holder and
    # sync after it saves. The association form input submits `rbac_role_sgids`,
    # whose writer assigns `rbac_roles=`, so it stages too, as do Plutonium's
    # `add_rbac_role_sgid` / `remove_rbac_role_sgid`.
    #
    # Rails' `rbac_role_assignments=` / `rbac_role_assignment_ids=` raise:
    # they re-point other holders' assignment rows instead of creating new ones.
    module Holder
      extend ActiveSupport::Concern

      included do
        has_many :rbac_role_assignments, class_name: "Plutonium::Rbac::RoleAssignment", as: :holder, dependent: :destroy
        has_many :rbac_roles, through: :rbac_role_assignments, source: :role
        # After has_many, so it wins over the sgid helpers Plutonium's
        # has_many generates.
        include StagedRoleSgids

        validate :validate_staged_rbac_roles
        after_save :sync_staged_rbac_roles
      end

      module StagedRoleSgids
        def add_rbac_role_sgid(sgid)
          role = GlobalID::Locator.locate_signed(sgid)
          self.rbac_role_ids = rbac_role_ids + [rbac_role_id_for(role)] if role
        end

        def remove_rbac_role_sgid(sgid)
          role = GlobalID::Locator.locate_signed(sgid)
          self.rbac_role_ids = rbac_role_ids - [rbac_role_id_for(role)] if role
        end
      end

      # The tenant this holder belongs to; tenant roles must match it.
      # Override (the installer generates one for membership holders).
      def rbac_entity = nil

      def rbac_permission_keys = Current.permission_keys_for(self)

      def rbac_permission_keys_uncached
        return Set.new if new_record?

        rbac_roles.pluck(:permissions).flatten.to_set
      end

      def rbac_granted?(key) = Matcher.grants?(rbac_permission_keys, key.to_s)

      def rbac_role_ids = @staged_rbac_role_ids || rbac_role_assignments.pluck(:role_id)

      # Ids that are not integers fail validation rather than raising here.
      def rbac_role_ids=(ids)
        ids = Array(ids).compact_blank.map { |id| Integer(id.to_s, 10, exception: false) }
        @invalid_rbac_role_ids = ids.include?(nil)
        @staged_rbac_role_ids = ids.compact.uniq
      end

      def rbac_roles=(roles)
        self.rbac_role_ids = Array(roles).map { |role| rbac_role_id_for(role) }
      end

      def rbac_role_assignments=(_assignments)
        raise ArgumentError, "Assign roles with rbac_roles= or rbac_role_ids=, not rbac_role_assignments="
      end

      def rbac_role_assignment_ids=(_ids)
        raise ArgumentError, "Assign roles with rbac_role_ids= or rbac_roles=, not rbac_role_assignment_ids="
      end

      private

      def rbac_role_id_for(role)
        unless role.is_a?(Role)
          raise ActiveRecord::AssociationTypeMismatch,
            "Plutonium::Rbac::Role expected, got #{role.inspect} which is an instance of #{role.class}"
        end

        role.id
      end

      def validate_staged_rbac_roles
        return if @staged_rbac_role_ids.nil?

        errors.add(:rbac_roles, :invalid) if @invalid_rbac_role_ids

        roles = Role.where(id: @staged_rbac_role_ids).to_a
        errors.add(:rbac_roles, :invalid) if roles.size != @staged_rbac_role_ids.size

        existing = new_record? ? [] : rbac_role_assignments.pluck(:role_id)
        roles.reject { |role| existing.include?(role.id) }.each do |role|
          assignment = RoleAssignment.new(holder: self, role:)
          next if assignment.valid?

          assignment.errors.each { |error| errors.add(:rbac_roles, error.message) }
        end
      end

      # Assignment commits invalidate the permission cache (RoleAssignment's
      # after_commit).
      def sync_staged_rbac_roles
        ids = @staged_rbac_role_ids
        return if ids.nil?

        @staged_rbac_role_ids = nil
        existing = rbac_role_assignments.pluck(:role_id)
        rbac_role_assignments.where(role_id: existing - ids).destroy_all
        (ids - existing).each { |role_id| rbac_role_assignments.create!(role_id:) }
      end
    end
  end
end
