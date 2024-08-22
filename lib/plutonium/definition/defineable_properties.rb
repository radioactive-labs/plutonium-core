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
    module DefineableProperties
      extend ActiveSupport::Concern

      included do
        class_attribute :defineable_properties, default: []
      end

      class_methods do
        # Defines a new property type for the class
        #
        # @param property_name [Symbol] The name of the property to define
        # @return [void]
        def defineable_property(property_name)
          property_plural = property_name.to_s.pluralize.to_sym
          self.defineable_properties += [property_plural]

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def self.#{property_name}(name, **options, &block)
              #{property_plural}[name] = { options: options, block: block }.compact
            end

            def self.#{property_plural}
              @#{property_plural} ||= {}
            end

            def #{property_name}(name, **options, &block)
              instance_#{property_plural}[name] = { options: options, block: block }.compact
            end

            def #{property_plural}
              merged = {}
              self.class.#{property_plural}.each do |name, data|
                merged[name] = {
                  options: data[:options].dup,
                  block: data[:block]
                }.compact
              end
              instance_#{property_plural}.each do |name, data|
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

            def customize_#{property_plural}
              # Override in subclass to add or modify #{property_plural}
            end

            private

            def instance_#{property_plural}
              @instance_#{property_plural} ||= {}
            end
          RUBY
        end

        # Handles inheritance by duplicating class-level collections
        #
        # @param subclass [Class] The inheriting subclass
        # @return [void]
        def inherited(subclass)
          super
          defineable_properties.each do |property|
            subclass.instance_variable_set(:"@#{property}", instance_variable_get(:"@#{property}")&.deep_dup || {})
          end
        end
      end

      def initialize
        customize_definitions
      end

      # Customizes all defined properties
      #
      # @return [void]
      def customize_definitions
        self.class.defineable_properties.each do |property|
          send(:"customize_#{property}")
        end
      end
    end
  end
end
