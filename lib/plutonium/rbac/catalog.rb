# frozen_string_literal: true

module Plutonium
  module Rbac
    # Every grantable permission key, derived from code.
    #
    # Sources: each resource governed by at least one policy that includes
    # Plutonium::Rbac::Policy gets the standard permissions; every action
    # declared on any of its definitions (base or portal) that is not one of
    # Plutonium's built-in actions becomes a permission; restricted attributes
    # declared on its RBAC policies add <field>.read/<field>.write; plus
    # anything declared through Plutonium::Rbac.permission. A resource whose
    # policies do not use RBAC would only add keys that grant nothing.
    #
    # Built lazily (it needs the app eager loaded) and reset on reload.
    class Catalog
      STANDARD_ACTIONS = %i[read create update destroy export].freeze

      class << self
        def instance = @instance ||= new.tap(&:build)

        def reset! = @instance = nil

        delegate :permissions, :keys, :key?, :grouped, :custom_actions_for, to: :instance
      end

      attr_reader :permissions, :keys

      def build
        # Every build, not Plutonium.eager_load_rails!: that one is memoized,
        # and a rebuild after a development reload must load the new classes.
        Rails.application.eager_load! unless Rails.application.config.eager_load
        # Gem-shipped, so the app's eager load never reaches them; role
        # management is RBAC-gated like any other resource.
        Rbac::RoleDefinition
        Rbac::RolePolicy

        @custom_actions = Hash.new { |h, k| h[k] = Set.new }
        @restricted_fields = Hash.new { |h, k| h[k] = Set.new }
        @rbac_models = Set.new

        definitions.each do |definition|
          @custom_actions[definition.model_class_or_nil].merge(definition.defined_actions.keys - builtin_action_names)
        end

        rbac_policies.each do |policy|
          model = Rbac::Policy.resource_class_for(policy)
          next unless model

          @rbac_models << model
          @restricted_fields[model].merge(policy.rbac_restricted_attribute_names)
        end

        @permissions = resource_permissions + Rbac.declared_permissions.values
        @keys = @permissions.to_set(&:key)
      end

      def key?(key) = keys.include?(key)

      def grouped = permissions.group_by(&:group)

      def custom_actions_for(resource_class) = @custom_actions.fetch(resource_class) { Set.new }

      private

      def definitions
        Plutonium::Resource::Definition.descendants.select { |klass| klass.name && klass.model_class_or_nil }
      end

      def rbac_policies
        Plutonium::Resource::Policy.descendants.select { |klass| klass.name && klass < Rbac::Policy }
      end

      def builtin_action_names = Plutonium::Resource::Definition.defined_actions.keys

      def resource_permissions
        @rbac_models.sort_by(&:name).flat_map do |model|
          prefix = model.model_name.i18n_key.to_s
          group = model.model_name.human(count: 2)
          actions = STANDARD_ACTIONS + custom_actions_for(model).to_a.sort
          fields = @restricted_fields.fetch(model) { Set.new }.to_a.sort

          actions.map { |action|
            Permission.new(key: "#{prefix}.#{action}", resource: model, action:, label: action.to_s.humanize, group:)
          } + fields.flat_map { |field|
            %i[read write].map do |mode|
              Permission.new(key: "#{prefix}.#{field}.#{mode}", resource: model, action: :"#{field}.#{mode}",
                label: "#{model.human_attribute_name(field)} (#{mode})", group:)
            end
          }
        end
      end
    end
  end
end
