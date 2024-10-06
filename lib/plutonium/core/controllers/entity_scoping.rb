# frozen_string_literal: true

module Plutonium
  module Core
    module Controllers
      # EntityScoping module provides functionality for scoping controllers to specific entities.
      #
      # This module is designed to be included in controllers that need to operate within the context
      # of a specific entity, such as a user's organization or a project.
      #
      # @example Usage in a controller
      #   class MyController < ApplicationController
      #     include Plutonium::Core::Controllers::EntityScoping
      #   end
      module EntityScoping
        extend ActiveSupport::Concern

        included do
          before_action :remember_scoped_entity
          helper_method :current_scoped_entity
        end

        # Checks if the current engine is scoped to an entity.
        #
        # @return [Boolean] true if scoped to an entity, false otherwise
        def scoped_to_entity?
          current_engine.scoped_to_entity?
        end

        # Returns the strategy used for entity scoping.
        #
        # @return [Symbol] the scoping strategy
        def scoped_entity_strategy
          current_engine.scoped_entity_strategy
        end

        # Returns the parameter key used for entity scoping.
        #
        # @return [Symbol] the parameter key
        # @raise [NotImplementedError] if not scoped to an entity
        def scoped_entity_param_key
          ensure_legal_entity_scoping_method_access!(__method__)
          current_engine.scoped_entity_param_key
        end

        # Returns the class of the scoped entity.
        #
        # @return [Class] the scoped entity class
        # @raise [NotImplementedError] if not scoped to an entity
        def scoped_entity_class
          ensure_legal_entity_scoping_method_access!(__method__)
          current_engine.scoped_entity_class
        end

        private

        # Returns the session key used to store the scoped entity.
        #
        # @return [Symbol] the session key
        # @raise [NotImplementedError] if not scoped to an entity
        def scoped_entity_session_key
          ensure_legal_entity_scoping_method_access!(__method__)
          [current_package&.name&.underscore, "scoped_entity_id"].compact.join("__").to_sym
        end

        # Returns the current scoped entity for the request.
        #
        # @return [ActiveRecord::Base, nil] the current scoped entity or nil if not found
        # @raise [NotImplementedError] if not scoped to an entity or strategy is unknown
        def current_scoped_entity
          ensure_legal_entity_scoping_method_access!(__method__)
          # this method might be invoked even when not authenticated.
          # so let's guard against that.
          return unless current_user.present?

          @current_scoped_entity ||= fetch_current_scoped_entity
        end

        # Fetches the current scoped entity based on the scoping strategy.
        #
        # @return [ActiveRecord::Base, nil] the current scoped entity or nil if not found
        # @raise [NotImplementedError] if the scoping strategy is unknown
        def fetch_current_scoped_entity
          case scoped_entity_strategy
          when :path
            scoped_entity = fetch_entity_from_path
            authorize! scoped_entity, to: :read?
            scoped_entity
          when Symbol
            send(scoped_entity_strategy)
          else
            raise NotImplementedError, "Unknown scoped entity strategy: #{scoped_entity_strategy.inspect}"
          end
        end

        # Fetches the scoped entity from the path parameters.
        #
        # @return [ActiveRecord::Base] the scoped entity
        # @raise [ActiveRecord::RecordNotFound] if the entity is not found or the user doesn't have access
        def fetch_entity_from_path
          scoped_entity_class
            .associated_with(current_user)
            .from_path_param(request.path_parameters[scoped_entity_param_key])
            .first!
        end

        # Remembers the current scoped entity in the session.
        #
        # @return [void]
        def remember_scoped_entity
          return unless scoped_to_entity?

          session[scoped_entity_session_key] = current_scoped_entity.to_global_id.to_s
        end

        # Retrieves the remembered scoped entity from the session.
        #
        # @return [ActiveRecord::Base, nil] the remembered scoped entity or nil if not found
        # @raise [NotImplementedError] if not scoped to an entity
        def remembered_scoped_entity
          ensure_legal_entity_scoping_method_access!(__method__)
          @remembered_scoped_entity ||= GlobalID::Locator.locate(session[scoped_entity_session_key])
        end

        # Ensures that the method call is legal within the current scoping context.
        #
        # @param method [Symbol] the method being called
        # @raise [NotImplementedError] if not scoped to an entity
        def ensure_legal_entity_scoping_method_access!(method)
          return if scoped_to_entity?

          raise NotImplementedError, <<~ERROR_MESSAGE
            This request is not scoped to an entity.

            Add the `scope_to_entity YourEntityRecord` directive in #{current_engine}
            or implement #{self.class}##{method}
          ERROR_MESSAGE
        end
      end
    end
  end
end
