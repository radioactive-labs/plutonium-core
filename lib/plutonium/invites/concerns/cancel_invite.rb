# frozen_string_literal: true

module Plutonium
  module Invites
    module Concerns
      # CancelInvite provides the cancel invitation interaction logic.
      #
      # Include this concern in your cancel interaction and override methods
      # as needed for customization.
      #
      # @example Basic usage
      #   class CancelInviteInteraction < Plutonium::Resource::Interaction
      #     include Plutonium::Invites::Concerns::CancelInvite
      #   end
      #
      module CancelInvite
        extend ActiveSupport::Concern

        included do
          presents label: t("plutonium.invites.cancel_invite.label"), icon: Phlex::TablerIcons::CircleX

          attribute :resource
        end

        def execute
          unless resource.pending?
            return failed(not_pending_message)
          end

          resource.cancelled!
          succeed(resource).with_message(success_message)
        end

        private

        def success_message
          I18n.t("plutonium.invites.cancel_invite.cancelled")
        end

        def not_pending_message
          I18n.t("plutonium.invites.cancel_invite.not_pending")
        end
      end
    end
  end
end
