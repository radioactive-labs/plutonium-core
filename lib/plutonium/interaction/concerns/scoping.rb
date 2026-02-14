# frozen_string_literal: true

module Plutonium
  module Interaction
    module Concerns
      # Scoping concern provides access to scoped records from the controller context.
      #
      # This handles both:
      # - Entity scoping: Portal-level multi-tenancy via `scope_to_entity` (accessed via `current_scoped_entity`)
      # - Parent scoping: Nested routes (accessed via `current_parent`)
      #
      # The `scoped_record_of_type` method checks both contexts and ensures type safety.
      #
      # @example Using in an interaction
      #   class MyInteraction < Plutonium::Resource::Interaction
      #     include Plutonium::Interaction::Concerns::Scoping
      #
      #     def execute
      #       organization = scoped_record_of_type(Organization)
      #       # Returns the Organization from either entity or parent scope
      #     end
      #   end
      #
      module Scoping
        extend ActiveSupport::Concern

        private

        # Returns a scoped record that matches the expected type.
        #
        # Checks both entity scoping (`current_scoped_entity`) and parent scoping (`current_parent`),
        # returning the first match that is an instance of the specified class.
        #
        # @param klass [Class] the expected model class
        # @return [Object, nil] the scoped record if found and type matches, nil otherwise
        def scoped_record_of_type(klass)
          [current_scoped_entity, current_parent].find { |record| record.is_a?(klass) }
        end

        # Returns the parent record from the controller (nested routes).
        #
        # @return [Object, nil] the current parent or nil
        def current_parent
          view_context.controller.current_parent
        rescue NoMethodError
          nil
        end

        # Returns the entity record from the controller (portal multi-tenancy).
        #
        # @return [Object, nil] the current scoped entity or nil
        def current_scoped_entity
          view_context.controller.current_scoped_entity
        rescue NoMethodError
          nil
        end

        # Returns the appropriate parent for URL generation.
        # Prefers entity scope over parent scope.
        #
        # @return [Object, nil] the entity or parent, whichever is available
        def scoped_parent
          current_scoped_entity || current_parent
        end
      end
    end
  end
end
