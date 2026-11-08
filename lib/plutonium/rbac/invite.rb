# frozen_string_literal: true

module Plutonium
  module Rbac
    # Include in an invite model (alongside Invites::Concerns::InviteToken).
    # The pending invite holds the chosen roles; on acceptance they move to the
    # new membership inside accept_for_user!'s lock/transaction.
    module Invite
      extend ActiveSupport::Concern

      included do
        include Plutonium::Rbac::Holder
        prepend MembershipTransfer
      end

      # Tenant roles must match the invite's tenant.
      def rbac_entity = entity

      module MembershipTransfer
        def create_membership_for(user)
          membership = super
          rbac_role_assignments.update_all(holder_type: membership.class.polymorphic_name, holder_id: membership.id.to_s)
          Current.invalidate!
          membership
        end
      end
    end
  end
end
