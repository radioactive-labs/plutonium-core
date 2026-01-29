# frozen_string_literal: true

module Plutonium
  module Invites
    module Concerns
      # InviteToken provides core invite functionality for models.
      #
      # This concern handles:
      # - Token generation and validation
      # - State machine (pending, accepted, expired, cancelled)
      # - Email constraint validation
      # - Invite acceptance flow
      #
      # @example Basic usage
      #   class UserInvite < ApplicationRecord
      #     include Plutonium::Resource::Record
      #     include Plutonium::Invites::Concerns::InviteToken
      #
      #     belongs_to :entity
      #     belongs_to :invited_by, polymorphic: true
      #     belongs_to :user, optional: true
      #     belongs_to :invitable, polymorphic: true, optional: true
      #
      #     enum :role, member: 0, admin: 1
      #
      #     def invitation_mailer
      #       UserInviteMailer
      #     end
      #
      #     def create_membership_for(user)
      #       EntityMembership.create!(entity: entity, user: user, role: role)
      #     end
      #   end
      #
      module InviteToken
        extend ActiveSupport::Concern

        included do
          # State machine for invite lifecycle
          enum :state, pending: 0, accepted: 1, expired: 2, cancelled: 3

          # Callbacks
          before_validation :set_token_defaults, on: :create
          after_create :send_invitation_email

          # Core validations
          validates :email, presence: true
          validates :token, presence: true
          validates :state, presence: true
        end

        class_methods do
          # Find a valid invitation for acceptance.
          #
          # Returns nil if the token is invalid, expired, or already accepted.
          # Automatically marks expired invites as expired.
          #
          # @param token [String] the invitation token
          # @return [Object, nil] the invite record or nil
          def find_for_acceptance(token)
            return nil if token.blank?

            invite = find_by(token: token)
            return nil unless invite

            # Check if invitation is expired
            if invite.expires_at && invite.expires_at < Time.current
              invite.expired! if invite.pending?
              return nil
            end

            # Only pending invites can be accepted
            return nil unless invite.pending?

            invite
          end
        end

        # Override in subclass to enforce email domain matching.
        #
        # @return [String, nil] the domain to enforce, or nil to skip domain check
        def enforce_domain
          nil
        end

        # Override in subclass to require exact email match.
        #
        # @return [Boolean] true to require exact email match
        def enforce_email?
          true
        end

        # Validate email constraints against the accepting user's email.
        #
        # @param user_email [String] the email of the user accepting the invite
        # @raise [ActiveRecord::RecordInvalid] if constraints are violated
        def validate_email_constraints!(user_email)
          if enforce_email? && user_email.downcase != email.downcase
            errors.add(:base, "This invitation is for #{email}. You must use an account with that email address.")
            raise ActiveRecord::RecordInvalid.new(self)
          end

          if (required_domain = enforce_domain)
            user_domain = extract_domain(user_email)

            if user_domain != required_domain
              errors.add(:base, "This invitation requires an email from the #{required_domain} domain.")
              raise ActiveRecord::RecordInvalid.new(self)
            end
          end
        end

        # Accept the invitation for a user.
        #
        # This method:
        # 1. Validates email constraints
        # 2. Marks the invite as accepted
        # 3. Creates the entity membership
        # 4. Notifies the invitable (if present)
        #
        # @param user [Object] the user accepting the invitation
        # @raise [ActiveRecord::RecordInvalid] if acceptance fails
        def accept_for_user!(user)
          validate_email_constraints!(user.email)

          transaction do
            update!(
              state: :accepted,
              accepted_at: Time.current,
              user: user
            )

            create_membership_for(user)
            notify_invitable(user)
          end
        end

        # Override this method to specify the mailer class.
        #
        # @return [Class] the mailer class for sending invitation emails
        # @raise [NotImplementedError] if not overridden
        def invitation_mailer
          raise NotImplementedError, "#{self.class}#invitation_mailer must be implemented to return the mailer class"
        end

        # Override this method to create the entity membership.
        #
        # @param user [Object] the user who accepted the invitation
        # @raise [NotImplementedError] if not overridden
        def create_membership_for(user)
          raise NotImplementedError, "#{self.class}#create_membership_for must be implemented to create the membership record"
        end

        # Alias method for the entity association.
        # Override if your entity association has a different name.
        #
        # @return [Object] the entity record
        def entity
          raise NotImplementedError, "#{self.class}#entity must be implemented or an entity association must exist"
        end

        private

        def extract_domain(email)
          return nil unless email&.include?("@")
          email.split("@").last&.downcase
        end

        def set_token_defaults
          self.token ||= SecureRandom.urlsafe_base64(32)
          self.expires_at ||= 1.week.from_now
        end

        def send_invitation_email
          invitation_mailer.invitation(self).deliver_later
        end

        def notify_invitable(user)
          return unless invitable_id.present?

          invitable.on_invite_accepted(user)
        end
      end
    end
  end
end
