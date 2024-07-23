require "action_policy"

module Plutonium
  module Resource
    module Controllers
      module Authorizable
        extend ActiveSupport::Concern

        class ActionMissingAuthorizeCurrent < ActionPolicy::UnauthorizedAction
        end

        class ActionMissingCurrentAuthorizedScope < ActionPolicy::UnauthorizedAction
        end

        included do
          verify_authorized
          after_action :verify_authorize_current
          after_action :verify_current_authorized_scope, except: %i[new create]

          helper_method :current_policy, :permitted_attributes

          attr_writer :authorize_current_count
          attr_writer :current_authorized_scope_count

          protected :authorize_current_count=, :authorize_current_count
          protected :current_authorized_scope_count=, :current_authorized_scope_count
        end

        private

        def verify_authorize_current
          return if verify_authorized_skipped

          raise ActionMissingAuthorizeCurrent.new(controller_path, action_name) if authorize_current_count.zero?
        end

        def verify_current_authorized_scope
          return if verify_authorized_skipped

          raise ActionMissingCurrentAuthorizedScope.new(controller_path, action_name) if current_authorized_scope_count.zero?
        end

        def authorize_current_count
          @authorize_current_count ||= 0
        end

        def current_authorized_scope_count
          @current_authorized_scope_count ||= 0
        end

        def current_policy
          @current_policy ||= begin
            policy_subject = resource_record || resource_class
            policy_for(record: policy_subject, context: current_policy_context)
          end
        end

        def current_authorized_scope
          self.current_authorized_scope_count += 1
          authorized_scope(resource_class.all, context: current_policy_context)
        end

        def current_policy_context
          {scope: current_parent || entity_scope_for_authorize}
        end

        def authorize_current!(record, **options)
          options[:context] = (options[:context] || {}).deep_merge current_policy_context
          authorize! record, **options
          self.authorize_current_count += 1
        end

        def permitted_attributes
          @permitted_attributes ||= current_policy.send_with_report :"permitted_attributes_for_#{action_name}"
        end

        def permitted_associations
          @permitted_associations ||= current_policy.send_with_report :permitted_associations
        end
      end
    end
  end
end
