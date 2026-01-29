# frozen_string_literal: true

module Plutonium
  module Invites
    module Concerns
      # ResendInvite provides the core logic for resending invitations.
      #
      # Include this in your ResendInviteInteraction to get the default behavior,
      # then override methods as needed.
      #
      # @example Basic usage
      #   class ResendInviteInteraction < Plutonium::Resource::Interaction
      #     include Plutonium::Invites::Concerns::ResendInvite
      #   end
      #
      # @example With custom expiry
      #   class ResendInviteInteraction < Plutonium::Resource::Interaction
      #     include Plutonium::Invites::Concerns::ResendInvite
      #
      #     def new_expiry
      #       2.weeks.from_now
      #     end
      #   end
      #
      module ResendInvite
        extend ActiveSupport::Concern

        included do
          presents label: "Resend Invitation", icon: Phlex::TablerIcons::MailForward

          attribute :resource
        end

        def execute
          unless resource.pending?
            return failed("Can only resend pending invitations")
          end

          resource.update!(expires_at: new_expiry)
          send_invitation_email

          succeed(resource).with_message(success_message)
        rescue => error
          failed("Failed to resend: #{error.message}")
        end

        private

        # Override to customize expiry duration
        def new_expiry
          1.week.from_now
        end

        # Override to customize email sending
        def send_invitation_email
          resource.invitation_mailer.invitation(resource).deliver_later
        end

        # Override to customize success message
        def success_message
          "Invitation resent to #{resource.email}"
        end
      end
    end
  end
end
