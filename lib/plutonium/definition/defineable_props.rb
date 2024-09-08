# frozen_string_literal: true

module Plutonium
  module Definition
    # Module for handling defineable properties in Plutonium definitions
    #
    # @example
    #   class MyDefinition
    #     include DefineableProperties
    #
    #     defineable_property :field
    #     defineable_property :input
    #     defineable_property :filter
    #     defineable_property :scope
    #     defineable_property :sorter
    #   end
    module DefineableProps
      extend ActiveSupport::Concern

      included do
        class_attribute :_defineable_props_store, instance_accessor: false, instance_predicate: false, default: []
      end

      class_methods do
        def defineable_props(*property_names)
          property_names.each { |name| defineable_prop(name) }
        end

        # Defines a new property type for the class
        #
        # @param property_name [Symbol] The name of the property to define
        # @return [void]
        def defineable_prop(property_name)
          property_plural = property_name.to_s.pluralize.to_sym
          property_getter = :"defined_#{property_plural}"
          self._defineable_props_store += [property_plural]

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def self.#{property_name}(name, **options, &block)
              #{property_getter}[name] = { options:, block:}.compact
            end

            def self.#{property_getter}
              @#{property_getter} ||= {}
            end

            def #{property_name}(name, **options, &block)
              instance_#{property_getter}[name] = { options:, block:}.compact
            end

            def #{property_getter}
              @merged_#{property_getter} ||= begin
                customize_#{property_plural}
                merged = {}
                self.class.#{property_getter}.each do |name, data|
                  merged[name] = {
                    options: data[:options].dup,
                    block: data[:block]
                  }.compact
                end
                instance_#{property_getter}.each do |name, data|
                  if merged.key?(name)
                    merged[name][:options].merge!(data[:options])
                    merged[name][:block] = data[:block] if data[:block]
                  else
                    merged[name] = data
                  end
                  # merged[name].compact!
                end
                merged
              end
            end

            def customize_#{property_plural}
              # Override in subclass to add or modify #{property_plural}
            end

            private

            def instance_#{property_getter}
              @instance_#{property_getter} ||= {}
            end
          RUBY
        end

        # Handles inheritance by duplicating class-level collections
        def inherited(subclass)
          super
          _defineable_props_store.each do |property|
            subclass.instance_variable_set(:"@defined_#{property}", instance_variable_get(:"@defined_#{property}")&.deep_dup || {})
          end
        end
      end
    end
  end
end
