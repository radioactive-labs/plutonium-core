# frozen_string_literal: true

module Plutonium
  module Core
    module Controllers
      module Authorizable
        extend ActiveSupport::Concern
        include ActionPolicy::Controller

        included do
          authorize :user, through: :current_user
          authorize :scope, through: :entity_scope_for_authorize

          helper_method :policy_for, :authorized_resource_scope
        end

        private

        def authorized_resource_scope(resource, **options)
          raise ArgumentError("Expected resource to be a class inheriting ActiveRecord::Base") unless resource.instance_of?(Class) && resource < ActiveRecord::Base

          options[:with] ||= ActionPolicy.lookup(resource, namespace: authorization_namespace)
          resource = resource.all

          authorized_scope(resource, **options)
        end

        def entity_scope_for_authorize
          scoped_to_entity? ? current_scoped_entity : nil
        end

        def verify_authorized
          # we don't use action policy's inbuilt checks, so ensure they are neutered,
          # also ensures pundit checks are disabled.
        end
      end
    end
  end
end
