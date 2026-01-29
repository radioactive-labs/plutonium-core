# frozen_string_literal: true

module Plutonium
  module Invites
    # PendingInviteCheck provides post-login invitation handling.
    #
    # Include this in a controller that users land on after login
    # (e.g., WelcomeController, DashboardController) to check for
    # pending invitations stored in cookies.
    #
    # @example Basic usage
    #   class WelcomeController < ApplicationController
    #     include Plutonium::Invites::PendingInviteCheck
    #
    #     def index
    #       return if redirect_to_pending_invite!
    #
    #       # Normal post-login flow...
    #       redirect_to dashboard_path
    #     end
    #
    #     private
    #
    #     def invite_class
    #       Invites::UserInvite
    #     end
    #   end
    #
    module PendingInviteCheck
      extend ActiveSupport::Concern

      private

      # Check for a pending invitation and redirect if found.
      #
      # @return [Boolean] true if redirected, false otherwise
      def redirect_to_pending_invite!
        token = cookies.encrypted[:pending_invitation]
        return false unless token

        invite = invite_class.find_for_acceptance(token)

        if invite
          redirect_to invitation_path(token: token)
          true
        else
          cookies.delete(:pending_invitation)
          false
        end
      end

      # Returns the pending invite if one exists.
      #
      # @return [Object, nil] the pending invite or nil
      def pending_invite
        token = cookies.encrypted[:pending_invitation]
        return nil unless token

        invite = invite_class.find_for_acceptance(token)
        unless invite
          cookies.delete(:pending_invitation)
          return nil
        end

        invite
      end

      # Override to specify the invite model class.
      #
      # @return [Class] the invite model class
      def invite_class
        raise NotImplementedError, "#{self.class}#invite_class must return the invite model class"
      end
    end
  end
end
