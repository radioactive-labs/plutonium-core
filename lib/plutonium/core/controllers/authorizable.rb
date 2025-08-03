# frozen_string_literal: true

module Plutonium
  module Core
    module Controllers
      module Authorizable
        extend ActiveSupport::Concern
        include ::ActionPolicy::Controller

        included do
          authorize :user, through: :current_user
          authorize :entity_scope, through: :entity_scope_for_authorize

          helper_method :policy_for, :authorized_resource_scope
        end

        private

        # Use this when getting a scope for a resource that is not the current
        # Use this instead of authorized_scope directly
        def authorized_resource_scope(resource, relation: nil, **options)
          unless resource.instance_of?(Class) && resource < ActiveRecord::Base
            raise ArgumentError("Expected resource to be a class inheriting ActiveRecord::Base")
          end

          options[:with] ||= ::ActionPolicy.lookup(resource, namespace: authorization_namespace)
          relation ||= resource.all

          authorized_scope(relation, **options)
        end

        def entity_scope_for_authorize
          current_scoped_entity if scoped_to_entity?
        end

        def verify_authorized
          # we don't use action policy's inbuilt checks, so ensure they are neutered,
          # also ensures pundit checks are disabled.
        end
      end
    end
  end
end
