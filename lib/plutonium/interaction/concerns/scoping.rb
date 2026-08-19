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
      # == Precondition
      #
      # These methods read the controller the interaction is rendering in, so
      # they require a Plutonium controller: `current_scoped_entity` needs
      # Core::Controllers::EntityScoping (which Plutonium::Core::Controller
      # includes, portal or not), and `current_parent` needs
      # Plutonium::Resource::Controller. Called anywhere else they raise
      # NoMethodError, deliberately — see #current_parent. An interaction that
      # can run outside a resource controller must not ask for a parent.
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
        # Asks for the parent only if the entity did not already answer.
        #
        # "Prefers entity over parent" has to mean the parent is not consulted at
        # all when the entity matches, or the preference is only about which
        # answer wins rather than which questions get asked. The array form
        # evaluated both before looking at either, so a caller that wanted the
        # TENANT still walked view_context.controller.helpers for a parent whose
        # answer it then discarded.
        #
        # It also keeps the precondition above honest. #current_parent no longer
        # rescues, so it raises wherever Plutonium::Resource::Controller is not
        # in play — and every caller today is an interaction, which always runs
        # under one. Nothing reaches that raise now; asking lazily is what stops
        # a tenant-only caller from being the one that finds it.
        def scoped_record_of_type(klass)
          entity = current_scoped_entity
          return entity if entity.is_a?(klass)

          parent = current_parent
          parent if parent.is_a?(klass)
        end

        # Returns the parent record from the controller (nested routes).
        #
        # Reached through +helpers+, not off the controller: both readers are
        # PRIVATE controller methods published with +helper_method+ (see
        # Plutonium::Resource::Controller and Core::Controllers::EntityScoping),
        # so calling them on the controller raises NoMethodError.
        #
        # Which is exactly what it should do. Neither reader rescues, because the
        # two answers must never collapse: "there is no parent" and "I could not
        # determine the parent" look identical as nil, and for the tenant below
        # that identity is a fail-OPEN — a nil tenant drops the entity filter
        # rather than narrowing to one. A rescue here bought silence about a
        # broken call for as long as it shipped; the next visibility change or
        # typo would buy the same silence again.
        #
        # nil here means the route is not nested, which is the controller
        # answering rather than an error being swallowed.
        #
        # @return [Object, nil] the current parent, or nil on a non-nested route
        def current_parent
          view_context.controller.helpers.current_parent
        end

        # The association a nested child hangs off its parent, e.g. :comments for
        # /posts/5/comments.
        #
        # Reached through +helpers+ and unrescued for the same reasons as
        # #current_parent above, and always answered together with it: a policy
        # needs both halves or neither (Policy#default_relation_scope raises on
        # one alone).
        #
        # @return [Symbol, nil] nil on a non-nested route
        def current_nested_association
          view_context.controller.helpers.current_nested_association
        end

        # Returns the entity record from the controller (portal multi-tenancy).
        #
        # nil means the portal has NO tenant, never that one could not be found.
        #
        # @return [Object, nil] the current scoped entity, or nil in an un-scoped portal
        def current_scoped_entity
          controller = view_context.controller
          # Asking an un-scoped portal for its entity raises NotImplementedError
          # by design; "there is no tenant" is the honest answer for a caller
          # that only wants to know which one it is in.
          return nil unless controller.scoped_to_entity?

          controller.helpers.current_scoped_entity
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
