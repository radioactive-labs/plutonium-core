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
        end

        private

        def policy_namespace(scope)
          raise NotImplementedError, "policy_namespace"
        end

        def pundit_user
          resource_context
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

        def current_permitted_attributes
          @current_permitted_attributes ||= begin
            permitted_attributes = current_policy.send :"permitted_attributes_for_#{action_name}"
            permitted_attributes -= [parent_param_key, parent_param_key.to_s.gsub(/_id$/, "").to_sym] if current_parent.present?
            permitted_attributes
          end
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
