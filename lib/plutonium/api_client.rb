# frozen_string_literal: true

module Plutonium
  # ApiClient module provides concerns for building API client account interactions.
  #
  # @example Creating an API client interaction
  #   class ApiClient::CreateInteraction < Plutonium::Resource::Interaction
  #     include Plutonium::ApiClient::Concerns::CreateApiClient
  #
  #     def rodauth_name
  #       :api_client
  #     end
  #
  #     def api_client_class
  #       ApiClient
  #     end
  #   end
  #
  module ApiClient
  end
end
