# frozen_string_literal: true

module Plutonium
  module Invites
    module Concerns
      # Invitable allows any model to trigger invites and be notified on acceptance.
      #
      # This pattern is useful when you have a profile or record that needs to
      # invite a user and then connect itself to that user after acceptance.
      #
      # @example TenantProfile that invites users
      #   class TenantProfile < ApplicationRecord
      #     include Plutonium::Resource::Record
      #     include Plutonium::Invites::Concerns::Invitable
      #
      #     belongs_to :entity
      #     belongs_to :user, optional: true
      #
      #     def on_invite_accepted(user)
      #       update!(user: user)
      #     end
      #   end
      #
      # @example Creating an invite from an invitable
      #   tenant_profile.create_invite!(
      #     email: tenant_profile.email,
      #     entity: tenant_profile.entity,
      #     invited_by: current_user,
      #     role: :member,
      #     email_template: "tenant"
      #   )
      #
      module Invitable
        extend ActiveSupport::Concern

        included do
          # Association to the pending user invite for this record.
          # Scoped to pending only - cancelled/expired/accepted invites are kept for audit.
          has_one :user_invite, -> { pending }, class_name: "Invites::UserInvite", as: :invitable
        end

        # Create an invite for this invitable.
        #
        # If there's already a pending invite for this invitable, it will be
        # destroyed and replaced with a new one.
        #
        # @param email [String] the email address to invite
        # @param entity [Object] the entity to join
        # @param invited_by [Object] the user creating the invite
        # @param role [Symbol, String] the role to assign (default: nil, uses model default)
        # @param email_template [String, nil] optional template type for email customization
        # @return [Object] the created invite record
        def create_invite!(email:, entity:, invited_by:, role: nil, email_template: nil)
          # Cancel any existing pending invite first (association is already scoped to pending)
          user_invite&.cancelled!

          attrs = {
            email: email,
            entity: entity,
            invited_by: invited_by,
            email_template: email_template
          }
          attrs[:role] = role if role.present?

          create_user_invite!(attrs)
        end

        # Check if there's an active pending invite.
        #
        # @return [Boolean] true if there's a pending invite
        def has_pending_invite?
          user_invite.present?
        end

        # Check if this invitable can receive an invitation.
        #
        # Override this method to customize the logic. The default implementation
        # returns true if no user is attached and no pending invite exists.
        #
        # @return [Boolean] true if invitation can be sent
        def can_invite_user?
          !user.present? && !has_pending_invite?
        end

        # Called when the invited user accepts and joins the entity.
        #
        # Override this method in your model to handle the acceptance,
        # typically to connect the invitable to the user.
        #
        # @param user [Object] the user who accepted the invite
        # @raise [NotImplementedError] if not overridden
        def on_invite_accepted(user)
          raise NotImplementedError, "#{self.class.name} must implement #on_invite_accepted(user)"
        end
      end
    end
  end
end
