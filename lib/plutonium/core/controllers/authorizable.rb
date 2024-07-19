require "action_policy"

module Plutonium
  module Core
    module Controllers
      module Authorizable
        extend ActiveSupport::Concern
        include ActionPolicy::Controller

        included do
          authorize :user, through: :current_user
          authorize :resource_context

          helper_method :policy_for, :authorized_scope_for
        end

        private

        def authorized_scope_for(resource, **options)
          options = {type: :relation}.merge options
          authorized_scope(resource, **options)
        end
      end
    end
  end
end
