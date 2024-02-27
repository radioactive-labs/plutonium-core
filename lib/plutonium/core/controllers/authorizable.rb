require "pundit"

module Plutonium
  module Core
    module Controllers
      module Authorizable
        extend ActiveSupport::Concern
        include Pundit::Authorization

        included do
          after_action :verify_authorized
          after_action :verify_policy_scoped, except: %i[new create]

          helper_method :permitted_attributes
          helper_method :current_policy
        end

        private

        def policy_namespace(scope)
          raise NotImplementedError, "policy_namespace"
        end

        def policy_context
          Plutonium::Reactor::PolicyContext.new(
            user: current_user,
            resource_context: resource_context
          )
        end

        def pundit_user
          policy_context
        end

        def policy(scope)
          super(policy_namespace(scope))
        end

        def policy_scope(scope)
          super(policy_namespace(scope))
        end

        def authorize(record, query = nil)
          super(policy_namespace(record), query)
        end

        def permitted_attributes
          @permitted_attributes ||= current_policy.send :"permitted_attributes_for_#{action_name}"
        end

        def current_policy
          @current_policy ||= begin
            policy_subject = resource_record || resource_class
            policy(policy_subject)
          end
        end

        def parent_policy
          @parent_policy ||= policy(current_parent) if current_parent.present?
        end
      end
    end
  end
end
