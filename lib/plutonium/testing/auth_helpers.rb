# frozen_string_literal: true

module Plutonium
  module Testing
    module AuthHelpers
      extend ActiveSupport::Concern

      def login_as(account, portal: nil)
        portal ||= current_portal
        if respond_to?(:sign_in_for_tests)
          sign_in_for_tests(account, portal: portal)
        else
          default_rodauth_login(account, portal: portal)
        end
        instance_variable_set(:"@__current_account_#{portal}", account)
      end

      def sign_out(portal: nil)
        portal ||= current_portal
        post logout_path_for(portal)
        follow_redirect! if response.redirect?
        instance_variable_set(:"@__current_account_#{portal}", nil)
      end

      def current_account(portal: nil)
        portal ||= current_portal
        instance_variable_get(:"@__current_account_#{portal}")
      end

      def with_portal(portal)
        prev = @__portal_override
        @__portal_override = portal
        yield
      ensure
        @__portal_override = prev
      end

      private

      def default_rodauth_login(account, portal:)
        post login_path_for(portal), params: {email: account.email, password: "password123"}
        follow_redirect! if response.redirect?
      end

      def login_path_for(portal)
        "/#{account_table_for(portal)}/login"
      end

      def logout_path_for(portal)
        "/#{account_table_for(portal)}/logout"
      end

      def account_table_for(portal)
        case portal
        when :admin then "admins"
        when :user, :org then "users"
        else portal.to_s.pluralize
        end
      end
    end
  end
end
