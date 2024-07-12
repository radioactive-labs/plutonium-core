# frozen_string_literal: true

module Plutonium
  module Pkg
    module Concerns
      # Provides methods for validating Plutonium resources
      module ResourceValidatable
        extend ActiveSupport::Concern

        # Custom error class for invalid resources
        class InvalidResourceError < StandardError; end

        private

        # Validates if a given resource is a valid Plutonium::Resource::Record
        #
        # @param resource [Object] The resource to validate
        # @raise [InvalidResourceError] If the resource is not valid
        # @return [void]
        def validate_resource!(resource)
          unless valid_resource?(resource)
            raise InvalidResourceError, "#{resource} is not a valid Plutonium::Resource::Record"
          end
        end

        # Checks if a given resource is a valid Plutonium::Resource::Record
        #
        # @param resource [Object] The resource to check
        # @return [Boolean] True if the resource is valid, false otherwise
        def valid_resource?(resource)
          resource.is_a?(Class) && resource.include?(Plutonium::Resource::Record)
        end
      end
    end
  end
end
