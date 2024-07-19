# frozen_string_literal: true

module Plutonium
  module Portal
    # DynamicControllers module provides functionality for dynamically creating controller classes
    # when they are missing in the current module's namespace.
    #
    # @example Usage
    #   module MyApp
    #     include Plutonium::Portal::DynamicControllers
    #   end
    #
    #   # Now, MyApp::SomeController will be dynamically created if it doesn't exist,
    #   # inheriting from ::SomeController and including MyApp::Concerns::Controller
    #
    # @note This module is designed to be included in a parent module that represents
    #   a namespace for controllers.
    module DynamicControllers
      extend ActiveSupport::Concern

      class_methods do
        # Handles missing constant lookup, specifically for controller classes
        #
        # @param const_name [Symbol] The name of the missing constant
        # @return [Class, nil] The dynamically created controller class if applicable, otherwise nil
        # @raise [NameError] If the constant is not a controller and cannot be found
        def const_missing(const_name)
          if const_name.to_s.end_with?("Controller")
            create_dynamic_controller(const_name)
          else
            super
          end
        end

        private

        # Creates a dynamic controller class
        #
        # @param const_name [Symbol] The name of the controller class to create
        # @return [Class] The newly created controller class
        # @raise [NameError] If the parent controller or concerns module cannot be found
        def create_dynamic_controller(const_name)
          parent_controller = "::#{const_name}".constantize
          current_module = name
          const_full_name = "#{current_module}::#{const_name}"

          klass = Class.new(parent_controller) do
            # YARD documentation for the dynamically created controller
            # @!parse
            #   class DynamicController < ParentController
            #     include ParentModule::Concerns::Controller
            #     # Dynamically created controller for handling actions in the parent module
            #     #
            #     # This controller is created at runtime to handle requests within the parent namespace.
            #     # It inherits from the corresponding top-level controller (e.g., ::ClientsController for ParentModule::ClientsController).
            #     # It also includes ParentModule::Concerns::Controller.
            #     #
            #     # @note This class is created dynamically and may not have explicit method definitions.
            #   end
          end

          # Define the constant in the global namespace
          define_nested_constant(const_full_name, klass)

          # Include required modules
          concerns_module = "#{current_module}::Concerns::Controller".constantize
          route_helpers_module = "#{AdminApp}::Engine".constantize.routes.url_helpers
          klass.include route_helpers_module
          klass.include concerns_module

          # # Run the load hooks to include necessary modules and configurations
          # ActiveSupport.run_load_hooks(:action_controller, klass)

          log_controller_creation(const_full_name, parent_controller)
          const_full_name.constantize
        rescue => e
          Plutonium.logger.error "[plutonium] Failed to create dynamic controller: #{e.message}"
          raise
        end

        # Defines a constant in the global namespace, handling nested modules
        #
        # @param const_full_name [String] The full module name
        # @param value [Object] The value to assign to the constant
        def define_nested_constant(const_full_name, value)
          names = const_full_name.split("::")
          const_name = names.pop

          names.inject(Object) do |mod, name|
            if mod.const_defined?(name)
              mod.const_get(name)
            else
              mod.const_set(name, Module.new)
            end
          end.const_set(const_name, value)
        end

        # Logs the creation of a dynamic controller
        #
        # @param const_full_name [String] The full name of the created controller
        # @param parent_controller [Class] The parent controller class
        def log_controller_creation(const_full_name, parent_controller)
          Plutonium.logger.info "[plutonium] Dynamically created #{const_full_name} < #{parent_controller}"
        end
      end
    end
  end
end
