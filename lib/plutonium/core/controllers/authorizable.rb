require "pundit"

module Plutonium
  module Core
    module Controllers
      module Authorizable
        extend ActiveSupport::Concern
        include ::Pundit::Authorization

        included do
          after_action :verify_authorized
          after_action :verify_policy_scoped, except: %i[new create]

          helper_method :current_policy, :permitted_attributes
        end

        private

        def policy_context
          raise NotImplementedError, "policy_context"
        end

        def pundit_user
          policy_context
        end

        # @return [Plutonium::Pundit::Context] a new instance of {Plutonium::Pundit::Context} with the current user and package
        def pundit
          @pundit ||= Plutonium::Pundit::Context.new(
            package: current_package.present? ? current_package.to_s.underscore.to_sym : nil,
            user: pundit_user,
            policy_cache: ::Pundit::CacheStore::LegacyStore.new(policies)
          )
        end

        def permitted_attributes
          @permitted_attributes ||= current_policy.send_with_report :"permitted_attributes_for_#{action_name}"
        end

        def permitted_associations
          @permitted_associations ||= current_policy.permitted_associations
        end

        def current_policy
          @current_policy ||= begin
            policy_subject = resource_record || resource_class
            policy(policy_subject)
          end
        end

        # def parent_policy
        #   @parent_policy ||= policy(current_parent) if current_parent.present?
        # end
      end
    end
  end
end
