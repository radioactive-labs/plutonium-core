# frozen_string_literal: true

module Plutonium
  module Invites
    # Controller provides the invitation acceptance flow for controllers.
    #
    # This concern handles:
    # - Showing the invitation landing page
    # - Accepting invitations for logged-in users
    # - Signup flow for new users
    # - Cookie management for pending invitations
    #
    # @example Basic usage
    #   class UserInvitationsController < ApplicationController
    #     include Plutonium::Invites::Controller
    #
    #     layout "invitation"
    #
    #     private
    #
    #     def invite_class
    #       UserInvite
    #     end
    #
    #     def after_accept_path
    #       root_path
    #     end
    #
    #     def login_path
    #       rodauth.login_path
    #     end
    #   end
    #
    module Controller
      extend ActiveSupport::Concern

      included do
        helper_method :current_user if respond_to?(:helper_method)
      end

      # GET /invitations/:token
      #
      # Shows the invitation landing page. If the user is logged in,
      # shows the acceptance form. If not, shows signup/login options.
      def show
        return unless (@invite = load_and_validate_invite(params[:token]))

        # Store invitation token in cookie for later use
        cookies.encrypted[:pending_invitation] = {
          value: params[:token],
          expires: 1.hour.from_now
        }

        if current_user
          begin
            @invite.validate_email_constraints!(current_user.email)
            render :show
          rescue ActiveRecord::RecordInvalid => e
            @error_title = "Email Validation Error"
            @error_message = e.record.errors.full_messages.join(", ")
            render :error, status: :forbidden
          end
        else
          render :landing
        end
      end

      # POST /invitations/:token/accept
      #
      # Accepts the invitation for the currently logged-in user.
      def accept
        return unless (@invite = load_and_validate_invite(params[:token]))

        unless current_user
          redirect_to invitation_path(token: params[:token]),
            alert: "Please sign in to accept this invitation"
          return
        end

        @invite.accept_for_user!(current_user)
        cookies.delete(:pending_invitation)

        redirect_to after_accept_path,
          notice: "Invitation accepted! Welcome to #{@invite.entity.to_label}!"
      rescue ActiveRecord::RecordInvalid => e
        @error_title = "Acceptance Error"
        @error_message = e.record.errors.full_messages.join(", ")
        render :error, status: :forbidden
      end

      # GET/POST /invitations/:token/signup
      #
      # Handles new user signup directly from the invitation.
      def signup
        return unless (@invite = load_and_validate_invite(params[:token]))

        if request.post?
          handle_signup_submission
        else
          render :signup
        end
      end

      private

      # Load and validate an invite by token.
      #
      # @param token [String] the invitation token
      # @return [Object, nil] the invite or nil (renders error)
      def load_and_validate_invite(token)
        invite = invite_class.find_for_acceptance(token)

        unless invite
          @error_title = "Invalid or Expired Invitation"
          @error_message = "This invitation link is no longer valid. It may have expired or already been used."
          render :error, status: :not_found
          return nil
        end

        invite
      end

      # Handle the signup form submission.
      def handle_signup_submission
        email = @invite.enforce_email? ? @invite.email : params[:email]
        password = params[:password]
        password_confirmation = params[:password_confirmation]

        if password != password_confirmation
          flash.now[:alert] = "Passwords don't match"
          render :signup
          return
        end

        begin
          ActiveRecord::Base.transaction do
            existing_user = user_class.find_by(email: email)
            if existing_user
              flash.now[:alert] = "An account with this email already exists. Please sign in instead."
              render :signup
              return
            end

            user = create_user_for_signup(email, password)

            if user&.persisted?
              @invite.accept_for_user!(user)
              cookies.delete(:pending_invitation)
              sign_in_user(user)
              redirect_to after_accept_path
            else
              flash.now[:alert] = "Failed to create account"
              render :signup
            end
          end
        rescue ActiveRecord::RecordInvalid => e
          flash.now[:alert] = if e.record.is_a?(invite_class)
            e.record.errors.full_messages.join(", ")
          else
            "Failed to create account: #{e.record.errors.full_messages.join(", ")}"
          end
          render :signup
        rescue => e
          flash.now[:alert] = "Failed to create account: #{e.message}"
          render :signup
        end
      end

      # Override to specify the invite model class.
      #
      # @return [Class] the invite model class
      # @raise [NotImplementedError] if not overridden
      def invite_class
        raise NotImplementedError, "#{self.class}#invite_class must return the invite model class"
      end

      # Override to specify the user model class.
      #
      # @return [Class] the user model class
      def user_class
        User
      end

      # Override to customize redirect after acceptance.
      #
      # @return [String] the path to redirect to
      def after_accept_path
        "/"
      end

      # Override to customize the login path.
      #
      # @return [String] the login path
      def login_path
        "/login"
      end

      # Override to create a user during signup.
      #
      # This method should be overridden to integrate with your
      # authentication system (e.g., Rodauth).
      #
      # @param email [String] the user's email
      # @param password [String] the user's password
      # @return [Object] the created user
      def create_user_for_signup(email, password)
        raise NotImplementedError, "#{self.class}#create_user_for_signup must be implemented for signup flow"
      end

      # Override to sign in the user after signup.
      #
      # @param user [Object] the user to sign in
      def sign_in_user(user)
        # Override in controller to sign in the user
        # e.g., for Rodauth: rodauth.account_from_login(user.email); rodauth.login("signup")
      end

      # Override to return the current logged-in user.
      #
      # @return [Object, nil] the current user or nil
      def current_user
        nil
      end
    end
  end
end
