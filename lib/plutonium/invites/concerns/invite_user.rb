# frozen_string_literal: true

module Plutonium
  module Invites
    module Concerns
      # InviteUser provides the core logic for inviting users to an entity.
      #
      # Include this in your InviteUserInteraction and implement the required methods.
      #
      # @example Basic usage with polymorphic entity
      #   class Organization::InviteUserInteraction < Plutonium::Resource::Interaction
      #     include Plutonium::Invites::Concerns::InviteUser
      #
      #     def invite_class
      #       Invites::UserInvite
      #     end
      #
      #     def membership_class
      #       OrganizationMembership
      #     end
      #   end
      #
      module InviteUser
        extend ActiveSupport::Concern

        included do
          presents label: "Invite User", icon: Phlex::TablerIcons::Mail

          attribute :resource
          attribute :email

          validates :email, presence: true
          validate :role_is_present
          validate :user_not_already_member
          validate :no_pending_invitation
        end

        def execute
          attrs = {
            entity: entity,
            email: email,
            role: role,
            invited_by: current_user,
            **additional_invite_attributes
          }
          attrs[:invitable] = invitable if invitable.present?

          invite_class.create!(attrs)

          succeed(resource).with_message(success_message)
        rescue ActiveRecord::RecordInvalid => e
          failed(e.record.errors)
        end

        private

        # Override to specify the invite model class
        # @return [Class]
        def invite_class
          Invites::UserInvite
        end

        # Override to specify the membership model class
        # @return [Class]
        def membership_class
          EntityMembership
        end

        # Override to specify the user model class
        # @return [Class]
        def user_class
          User
        end

        # Override to specify how to get the entity from the resource.
        # By default assumes resource IS the entity.
        # @return [Object]
        def entity
          resource
        end

        # Override to specify the invitable (model that triggered the invite).
        # By default returns nil (no invitable).
        # @return [Object, nil]
        def invitable
          nil
        end

        # Override to specify the role to assign
        # @return [Symbol, String]
        def role
          raise NotImplementedError, "#{self.class}#role must return the role to assign"
        end

        # Override to add additional attributes when creating the invite
        # @return [Hash]
        def additional_invite_attributes
          {}
        end

        # Override to customize success message
        def success_message
          "Invitation sent to #{email}"
        end

        # Override to specify the entity association name on membership
        # @return [Symbol]
        def membership_entity_attribute
          entity.class.name.underscore.to_sym
        end

        def role_is_present
          errors.add(:role, :blank) if role.blank?
        end

        def user_not_already_member
          return unless email.present? && entity.present?

          existing_user = user_class.find_by(email: email)
          return unless existing_user

          membership = membership_class.find_by(
            membership_entity_attribute => entity,
            user_association => existing_user
          )
          errors.add(:email, "is already a member") if membership
        end

        def no_pending_invitation
          return unless email.present? && entity.present?

          pending = invite_class.find_by(
            entity: entity,
            email: email,
            state: :pending
          )
          errors.add(:email, "already has a pending invitation") if pending
        end

        # Override if user association has a different name
        def user_association
          :user
        end
      end
    end
  end
end
