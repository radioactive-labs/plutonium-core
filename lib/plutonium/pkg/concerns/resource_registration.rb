# frozen_string_literal: true

module Plutonium
  module Pkg
    module Concerns
      # The ResourceRegistration module provides functionality for registering and managing resources
      module ResourceRegistration
        extend ActiveSupport::Concern
        include Plutonium::Concerns::ResourceValidatable

        included do
          class_attribute :resource_register, default: ResourceRegister.new
        end

        class_methods do
          # Initializes the resource register by clearing all existing registrations.
          # This method is particularly useful for supporting hot reloads in development.
          #
          # @return [void]
          def initialize_register!
            resource_register.clear
          end

          # Registers a new resource with the package.
          #
          # @param resource [Class] The resource class to be registered.
          # @raise [ArgumentError] If the resource is not a valid Plutonium::Resource::Record.
          # @return [void]
          def register_resource(resource)
            validate_resource! resource

            resource_register.register(resource)
          end
        end
      end
    end
  end
end
