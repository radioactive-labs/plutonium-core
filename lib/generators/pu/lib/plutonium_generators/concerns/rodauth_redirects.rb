# frozen_string_literal: true

module PlutoniumGenerators
  module Concerns
    # Shared logic for updating Rodauth redirect configuration.
    # Used by generators that need to point login/create_account redirects to /welcome.
    module RodauthRedirects
      # Updates login_redirect and create_account_redirect in a Rodauth plugin file
      # to point to the given path (typically "/welcome").
      #
      # @param rodauth_file [String] relative path to the rodauth plugin file
      # @param redirect_path [String] the path to redirect to (default: "/welcome")
      def update_rodauth_redirects(rodauth_file, redirect_path: "/welcome")
        unless File.exist?(Rails.root.join(rodauth_file))
          say_status :skip, "Rodauth plugin not found: #{rodauth_file}", :yellow
          return
        end

        file_content = File.read(Rails.root.join(rodauth_file))

        # Update login_redirect
        if file_content.match?(/login_redirect\s+["']\/["']/)
          gsub_file rodauth_file,
            /login_redirect\s+["']\/["']/,
            "login_redirect \"#{redirect_path}\""
        end

        # Update or add create_account_redirect
        if file_content.include?("create_account_redirect")
          gsub_file rodauth_file,
            /create_account_redirect\s+["']\/["']/,
            "create_account_redirect \"#{redirect_path}\""
        elsif file_content.include?("login_redirect")
          inject_into_file rodauth_file,
            "\n    create_account_redirect \"#{redirect_path}\"\n",
            after: /login_redirect.*\n/
        end
      end
    end
  end
end
