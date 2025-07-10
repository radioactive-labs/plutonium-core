# frozen_string_literal: true

module Plutonium
  module Engine
    extend ActiveSupport::Concern

    class_methods do
      attr_reader :scoped_entity_class, :scoped_entity_strategy, :scoped_entity_param_key, :scoped_entity_route_key

      def scope_to_entity(entity_class, strategy: :path, param_key: nil, route_key: nil)
        @scoped_entity_class = entity_class
        @scoped_entity_strategy = strategy
        @scoped_entity_param_key = param_key || entity_class.model_name.singular_route_key.to_sym
        @scoped_entity_route_key = route_key || entity_class.model_name.singular.to_sym
      end

      def scoped_to_entity?
        scoped_entity_class.present?
      end

      def dom_id
        module_parent_name.underscore.dasherize
      end
    end
  end
end
