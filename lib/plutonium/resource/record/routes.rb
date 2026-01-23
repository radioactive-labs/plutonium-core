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
          # Returns metadata for has_many associations that can be routed
          # @return [Array<Hash>] Array of hashes with :name, :klass, :plural keys
          def routable_has_many_associations
            return @routable_has_many_associations if defined?(@routable_has_many_associations) && !Rails.env.local?

            @routable_has_many_associations = reflect_on_all_associations(:has_many).map do |assoc|
              {name: assoc.name, klass: assoc.klass, plural: assoc.klass.model_name.plural}
            end
          end

          # Returns metadata for has_one associations that can be routed
          # @return [Array<Hash>] Array of hashes with :name, :klass, :plural keys
          def routable_has_one_associations
            return @routable_has_one_associations if defined?(@routable_has_one_associations) && !Rails.env.local?

            @routable_has_one_associations = reflect_on_all_associations(:has_one)
              .reject { |assoc| assoc.options[:through] }
              .map do |assoc|
                {name: assoc.name, klass: assoc.klass, plural: assoc.klass.model_name.plural}
              end
          end

          # @deprecated Use routable_has_many_associations instead
          def has_many_association_routes
            return @has_many_association_routes if defined?(@has_many_association_routes) && !Rails.env.local?

            @has_many_association_routes = routable_has_many_associations.map { |info| info[:plural] }
          end

          # @deprecated Use routable_has_one_associations instead
          def has_one_association_routes
            return @has_one_association_routes if defined?(@has_one_association_routes) && !Rails.env.local?

            @has_one_association_routes = routable_has_one_associations.map { |info| info[:plural] }
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
