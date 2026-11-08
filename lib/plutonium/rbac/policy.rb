# frozen_string_literal: true

module Plutonium
  module Rbac
    # Policy mixin: core predicates and custom-action rules default to the
    # current holder's permissions.
    #
    #   class ResourcePolicy < Plutonium::Resource::Policy
    #     include Plutonium::Rbac::Policy
    #   end
    #
    # Combine a grant with record state by overriding and calling super:
    #
    #   def publish? = super && record.draft?
    module Policy
      extend ActiveSupport::Concern

      included do
        class_attribute :rbac_restricted_attribute_names, instance_accessor: false, default: [].freeze
        prepend AttributeFilter
      end

      class_methods do
        # Prepend onto subclasses too, so their own permitted_attributes_for_*
        # overrides are filtered.
        def inherited(subclass)
          super
          subclass.prepend(AttributeFilter)
        end

        # Fields hidden unless <resource>.<field>.read / .write is granted.
        def rbac_restricted_attributes(*names)
          self.rbac_restricted_attribute_names = (rbac_restricted_attribute_names + names.map(&:to_sym)).uniq.freeze
        end
      end

      # The model a policy class governs, inferred from its name the same way
      # Definition::Base infers a model: strip "Policy", then search outward
      # through the namespaces (OrgPortal::Blogging::PostPolicy -> Blogging::Post).
      def self.resource_class_for(policy_class)
        segments = policy_class.name.split("::")
        base = segments.pop.delete_suffix("Policy")
        segments.size.downto(0) do |i|
          klass = (segments.last(i) + [base]).join("::").safe_constantize
          return klass if klass.is_a?(Class) && klass < ActiveRecord::Base
        end
        nil
      end

      def read? = granted?(:read)

      def create? = granted?(:create)

      def update? = granted?(:update)

      def destroy? = granted?(:destroy)

      def export_csv? = granted?(:export)

      # A symbol expands to "<resource>.<action>"; a string is a full key.
      def granted?(action_or_key)
        key = action_or_key.is_a?(Symbol) ? "#{rbac_resource_key}.#{action_or_key}" : action_or_key.to_s
        Matcher.grants?(rbac_permission_keys, key)
      end

      # The holder resolved through ResourcePolicy#rbac_holder (or the portal's
      # override), so every policy in a portal agrees. Not named rbac_holder:
      # that would shadow the app's definition.
      def current_rbac_holder
        return @current_rbac_holder if defined?(@current_rbac_holder)

        @current_rbac_holder = Current.holder_for(user:, entity_scope:)
      end

      def rbac_permission_keys = Current.permission_override || Current.permission_keys_for(current_rbac_holder)

      def rbac_resource_key = resource_class.model_name.i18n_key.to_s

      def respond_to_missing?(name, include_private = false)
        rbac_custom_action(name) ? true : super
      end

      def method_missing(name, *args, &)
        action = rbac_custom_action(name)
        action ? granted?(action) : super
      end

      private

      def rbac_custom_action(name)
        name = name.to_s
        return unless name.end_with?("?")

        action = name.delete_suffix("?").to_sym
        action if Catalog.custom_actions_for(resource_class).include?(action)
      end
    end
  end
end
