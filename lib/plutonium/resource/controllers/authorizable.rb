# frozen_string_literal: true

module Plutonium
  module Resource
    module Controllers
      # The Authorizable module provides authorization functionality for controllers,
      # specifically for the current resource being handled by the controller.
      # It integrates with ActionPolicy to enforce authorization checks and scoping.
      #
      # @example Including the module in a controller
      #   class MyController < ApplicationController
      #     include Plutonium::Resource::Controllers::Authorizable
      #   end
      #
      # @note This module assumes the existence of methods like `resource_record!`,
      #   `resource_class`, `current_parent`, and `entity_scope_for_authorize`.
      #
      # @see ActionPolicy
      module Authorizable
        extend ActiveSupport::Concern

        # Custom exception for missing authorize_current call
        class ActionMissingAuthorizeCurrent < ::ActionPolicy::UnauthorizedAction; end

        # Custom exception for missing current_authorized_scope call
        class ActionMissingCurrentAuthorizedScope < ::ActionPolicy::UnauthorizedAction; end

        included do
          after_action :verify_authorize_current
          after_action :verify_current_authorized_scope, except: %i[new create]

          helper_method :current_policy, :permitted_attributes

          attr_writer :authorize_current_count
          attr_writer :current_authorized_scope_count

          attr_reader :verify_authorize_current_skipped
          attr_reader :verify_current_authorized_scope_skipped

          protected :authorize_current_count=, :authorize_current_count
          protected :current_authorized_scope_count=, :current_authorized_scope_count
        end

        class_methods do
          # Skips verify_authorize_current after_action callback.
          def skip_verify_authorize_current(**options)
            skip_after_action :verify_authorize_current, options
          end

          # Skips verify_current_authorized_scope after_action callback.
          def skip_verify_current_authorized_scope(**options)
            skip_after_action :verify_current_authorized_scope, options
          end
        end

        private

        def skip_verify_authorize_current!
          @verify_authorize_current_skipped = true
        end

        def skip_verify_current_authorized_scope!
          @verify_current_authorized_scope_skipped = true
        end

        # Verifies that authorize_current has been called
        #
        # @raise [ActionMissingAuthorizeCurrent] if authorize_current hasn't been called
        def verify_authorize_current
          return if verify_authorize_current_skipped
          return if authorize_current_count > 0

          raise ActionMissingAuthorizeCurrent.new(controller_path, action_name)
        end

        # Verifies that current_authorized_scope has been called
        #
        # @raise [ActionMissingCurrentAuthorizedScope] if current_authorized_scope hasn't been called
        def verify_current_authorized_scope
          return if verify_current_authorized_scope_skipped
          return if current_authorized_scope_count > 0

          raise ActionMissingCurrentAuthorizedScope.new(controller_path, action_name)
        end

        # @return [Integer] the number of times authorize_current has been called
        def authorize_current_count
          @authorize_current_count ||= 0
        end

        # @return [Integer] the number of times current_authorized_scope has been called
        def current_authorized_scope_count
          @current_authorized_scope_count ||= 0
        end

        # Returns the policy for the current resource
        #
        # @return [::ActionPolicy::Base] the policy for the current resource
        def current_policy
          @current_policy ||= policy_for(record: current_policy_subject, context: current_policy_context)
        end

        # Returns the authorized scope for the current resource
        #
        # @return [ActiveRecord::Relation] the authorized scope for the current resource
        def current_authorized_scope
          self.current_authorized_scope_count += 1
          authorized_scope(resource_class.all, context: current_policy_context)
        end

        # Sets the policy context scope value to the current parent if available
        #
        # @return [Hash] default context for the current resource's policy
        def current_policy_context
          {entity_scope: current_parent || entity_scope_for_authorize}
        end

        # Authorizes the current action for the given record of the current resource
        #
        # @param record [Object] the record to authorize
        # @param options [Hash] additional options for authorization
        # @raise [::ActionPolicy::Unauthorized] if the action is not authorized
        def authorize_current!(record, **options)
          options[:context] = (options[:context] || {}).deep_merge(current_policy_context)
          authorize!(record, **options)
          self.authorize_current_count += 1
        end

        # Returns the list of permitted attributes for the current action on the current resource
        #
        # @return [Array<Symbol>] the list of permitted attributes for the current action
        def permitted_attributes
          @permitted_attributes ||= current_policy.send_with_report(:"permitted_attributes_for_#{action_name}").freeze
        end

        # Returns the list of permitted associations for the current resource
        #
        # @return [Array<Symbol>] the list of permitted associations
        def permitted_associations
          @permitted_associations ||= current_policy.send_with_report(:permitted_associations)
        end

        # Returns the subject for the current resource's policy
        #
        # @return [Object] the subject for the policy (either resource_record or resource_class)
        def current_policy_subject
          # We have an "inconsistency" here where resource_record?
          # will return an actual record instead of nil for routes such as :new when dealing with singular resources.
          # It impacts mainly attribute policies, such as when getting the allowed attributes for forms.
          # But while it is an an inconsistency, I believe it is expected behaviour.
          # You did mark the resource as singular after all.
          # So you should disable :create? in your policy when a record exists.
          resource_record? || resource_class
        end
      end
    end
  end
end
