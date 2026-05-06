# frozen_string_literal: true

module Plutonium
  module Invites
    # PendingInviteCheck provides post-login invitation handling.
    #
    # Include this in a controller that users land on after login
    # (e.g., WelcomeController, DashboardController) to check for
    # pending invitations stored in cookies.
    #
    # Hosts may override either `invite_classes` (preferred — returns
    # an Array of invite classes to check, in priority order) or
    # `invite_class` (single class, kept for backward compatibility).
    #
    # @example Single invite class
    #   def invite_class
    #     ::Invites::UserInvite
    #   end
    #
    # @example Multiple invite classes
    #   def invite_classes
    #     [::Invites::FunderInvite, ::Invites::SpenderInvite]
    #   end
    module PendingInviteCheck
      extend ActiveSupport::Concern

      included do
        append_view_path File.expand_path("app/views", Plutonium.root)
      end

      private

      # Check for a pending invitation and redirect if found.
      def redirect_to_pending_invite!
        token = cookies.encrypted[:pending_invitation]
        return false unless token

        if find_pending_invite(token)
          redirect_to invitation_path(token: token)
          true
        else
          cookies.delete(:pending_invitation)
          false
        end
      end

      # Returns the pending invite if one exists across any invite_classes.
      def pending_invite
        token = cookies.encrypted[:pending_invitation]
        return nil unless token

        invite = find_pending_invite(token)
        unless invite
          cookies.delete(:pending_invitation)
          return nil
        end

        invite
      end

      # Override to specify multiple invite model classes (preferred).
      # Defaults to `[invite_class]` for backward compatibility.
      # @return [Array<Class>]
      def invite_classes
        [invite_class]
      end

      # Override to specify a single invite model class. Maintained for
      # backward compatibility; prefer `invite_classes` for multi-flow apps.
      # @return [Class]
      def invite_class
        raise NotImplementedError,
          "#{self.class}#invite_class or #invite_classes must return the invite model class(es)"
      end

      def find_pending_invite(token)
        invite_classes.each do |klass|
          invite = klass.find_for_acceptance(token)
          return invite if invite
        end
        nil
      end
    end
  end
end
