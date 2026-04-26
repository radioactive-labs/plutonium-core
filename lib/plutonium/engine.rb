# frozen_string_literal: true

module Plutonium
  module Engine
    extend ActiveSupport::Concern

    class_methods do
      attr_reader :scoped_entity_strategy, :scoped_entity_param_key, :scoped_entity_route_key

      # Store the entity class *by name* and resolve it lazily on every call.
      # Capturing the class object directly causes stale references after Rails
      # autoreload: the constant is reloaded but @scoped_entity_class still
      # points at the previous (now-orphaned) class object, which then fails
      # type checks against freshly reloaded instances.
      def scope_to_entity(entity_class, strategy: :path, param_key: nil, route_key: nil)
        @scoped_entity_class_name = entity_class.is_a?(Class) ? entity_class.name : entity_class.to_s
        @scoped_entity_strategy = strategy
        # param_key / route_key are derived from the class once at declaration
        # time — they're stable strings and don't depend on the live class
        # identity, so caching them is safe.
        resolved = @scoped_entity_class_name.constantize
        @scoped_entity_param_key = param_key || :"#{resolved.model_name.singular_route_key}_scoped"
        @scoped_entity_route_key = route_key || resolved.model_name.singular.to_sym
      end

      def scoped_entity_class
        @scoped_entity_class_name&.constantize
      end

      def scoped_to_entity?
        @scoped_entity_class_name.present?
      end

      def dom_id
        module_parent_name.underscore.dasherize
      end
    end
  end
end
