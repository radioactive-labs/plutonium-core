# frozen_string_literal: true

# lib/plutonium/resource/associations.rb
module Plutonium
  module Resource
    module Record
      module Routes
        extend ActiveSupport::Concern

        included do
          scope :from_path_param, ->(param) { where(id: param) }
        end

        class_methods do
          def has_many_association_routes
            return @has_many_association_routes if defined?(@has_many_association_routes) && !Rails.env.local?

            @has_many_association_routes = reflect_on_all_associations(:has_many).map { |assoc| assoc.klass.model_name.plural }
          end

          def all_nested_attributes_options
            unless Rails.env.local?
              return @all_nested_attributes_options if defined?(@all_nested_attributes_options)
            end

            @all_nested_attributes_options = reflect_on_all_associations.map do |association|
              setter_method = "#{association.name}_attributes="
              if method_defined?(setter_method)
                [association.name, nested_attributes_options[association.name].merge(
                  macro: association.macro,
                  class: association.polymorphic? ? nil : association.klass
                )]
              end
            end.compact.to_h
          end

          private

          def path_parameter(param_name)
            param_name = param_name.to_sym

            scope :from_path_param, ->(param) { where(param_name => param) }

            define_method :to_param do
              return nil unless persisted?

              send(param_name)
            end
          end

          def dynamic_path_parameter(param_name)
            param_name = param_name.to_sym

            scope :from_path_param, ->(param) { where(id: param.split("-").first) }

            define_method :to_param do
              return nil unless persisted?

              "#{id}-#{send(param_name)}".parameterize
            end
          end
        end
      end
    end
  end
end
