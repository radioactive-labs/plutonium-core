# frozen_string_literal: true

module Plutonium
  module ApiClient
    module Concerns
      # DisableApiClient provides the core logic for disabling API client accounts.
      #
      # Include this in your DisableInteraction and implement the required methods.
      #
      # @example Basic usage
      #   class ApiClient::DisableInteraction < Plutonium::Resource::Interaction
      #     include Plutonium::ApiClient::Concerns::DisableApiClient
      #
      #     def rodauth_name
      #       :api_client
      #     end
      #   end
      #
      module DisableApiClient
        extend ActiveSupport::Concern

        included do
          presents label: "Disable",
            description: "Disable this API client (cannot be undone)",
            icon: Phlex::TablerIcons::Ban,
            color: :danger

          attribute :resource

          validates :resource, presence: true
        end

        def execute
          login = resource.login

          rodauth_instance.close_account(account_login: login)

          succeed(resource).with_message(success_message(login))
        rescue => e
          failed(base: e.message)
        end

        private

        # Override to specify the Rodauth configuration name
        # @return [Symbol]
        def rodauth_name
          raise NotImplementedError, "#{self.class}#rodauth_name must return the Rodauth configuration name (e.g., :api_client)"
        end

        # Override to customize success message
        # @param login [String] the login of the disabled API client
        # @return [String]
        def success_message(login)
          "API client '#{login}' has been disabled"
        end

        def rodauth_instance
          RodauthApp.rodauth(rodauth_name)
        end
      end
    end
  end
end
