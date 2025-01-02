# frozen_string_literal: true

module PlutoniumGenerators
  module Concerns
    module ResourceSelector
      def self.included(base)
        # base.send :class_option, :resources, type: :array, desc: "List of resource model names if applicable"
        base.send :argument, :resources, type: :array, optional: true, default: [],
          desc: "List of model names if applicable"
      end

      private

      def available_resources(source_module)
        Plutonium.eager_load_rails!

        source_module.constantize.descendants.reject do |model|
          next true if model.abstract_class?
          next true if source_module == "ApplicationRecord" &&
            model.ancestors.any? { |ancestor| ancestor.to_s.end_with?("::ResourceRecord") }
        end.map(&:to_s).sort
      end

      def select_resources(source_module, prompt: "Select resources")
        resources = available_resources(source_module)
        error "No resources found" if resources.blank?

        self.prompt.multi_select(prompt, resources)
      end

      def resources_selection(prompt: nil)
        ivar = :@resources_selection
        return instance_variable_get(ivar) if instance_variable_defined?(ivar)

        # Convert comma-separated string to array if from command line
        value = resources.map(&:classify)
        if value.empty?
          source_feature = feature_option :src, prompt: "Select source feature"
          source_module = (source_feature == "main_app") ? "ApplicationRecord" : "#{source_feature.camelize}::ResourceRecord"
          value = select_resources(source_module, prompt: prompt || "Select #{source_module} resources")
        end

        instance_variable_set(ivar, value)
        value
      end
    end
  end
end
