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
          presents label: "Cancel Invitation", icon: "outline/x-circle"
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
          "Invitation cancelled"
        end

        def not_pending_message
          "Can only cancel pending invitations"
        end
      end
    end
  end
end
