# frozen_string_literal: true

module Plutonium
  module Rbac
    # Include in an InviteUser interaction after Invites::Concerns::InviteUser.
    #
    #   include Plutonium::Invites::Concerns::InviteUser
    #   include Plutonium::Rbac::InviteUser
    #   input :rbac_role_ids, as: :select, multiple: true, choices: ...
    module InviteUser
      extend ActiveSupport::Concern

      included do
        attribute :rbac_role_ids, default: -> { [] }
      end

      private

      def additional_invite_attributes
        super.merge(rbac_role_ids:)
      end
    end
  end
end
