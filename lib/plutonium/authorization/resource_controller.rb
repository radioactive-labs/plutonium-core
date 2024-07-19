require "action_policy"

module Plutonium
  module Authorization
    module ResourceController
      extend ActiveSupport::Concern
      include Plutonium::Authorization::Controller

      included do
        verify_authorized
        # after_action :verify_policy_scoped, except: %i[new create]

        helper_method :current_policy, :permitted_attributes
      end

      private

      def current_policy
        @current_policy ||= begin
          policy_subject = resource_record || resource_class
          policy_for(record: policy_subject)
        end
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
