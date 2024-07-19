# frozen_string_literal: true

module Plutonium
  module Routing
    # The ResourceRegistration module provides functionality for registering and managing resources
    module ResourceRegistration
      extend ActiveSupport::Concern

      class_methods do
        def resource_register
          @resource_register ||= Plutonium::Resource::Register.new
        end
      end
    end
  end
end
