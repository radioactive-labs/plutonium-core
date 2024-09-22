module Plutonium
  module Core
    module Fields
      module Inputs
        class NestedInput < Base
          include Plutonium::Core::Definers::FieldInputDefiner

          attr_reader :inputs, :resource_class

          def initialize(name, inputs:, resource_class:, allow_destroy:, update_only:, limit:, **)
            @inputs = inputs
            @resource_class = resource_class
            @allow_destroy = allow_destroy
            @update_only = update_only
            @limit = limit

            super(name, **)
          end

          def render
            render_component :nested_resource_form_fields, form:, **options
          end

          def collect(params)
            nested_params = params[param] || {}
            attributes = (nested_params.keys.first == "0") ? collect_indexed_attributes(nested_params) : collect_single_attributes(nested_params)
            {param => attributes}
          end

          private

          def collect_single_attributes(params)
            collected = defined_inputs.collect_all(params)
            collected[:id] = params[:id] if params.key?(:id) && !@update_only
            collected[:_destroy] = params[:_destroy] if @allow_destroy
            collected
          end

          def collect_indexed_attributes(params)
            attributes = {}
            params.each do |index, nested_params|
              collected = defined_inputs.collect_all(nested_params)
              collected[:id] = nested_params[:id] if nested_params.key?(:id) && !@update_only
              collected[:_destroy] = nested_params[:_destroy] if @allow_destroy
              attributes[index] = collected
            end
            attributes
          end

          def param
            :"#{name}_attributes"
          end

          def input_options
            {
              name:,
              resource_class:,
              allow_destroy: @allow_destroy,
              update_only: @update_only,
              limit: @limit,
              inputs: defined_inputs
            }
          end

          def defined_inputs
            @defined_inputs ||= defined_field_inputs_for(*inputs)
          end
        end
      end
    end
  end
end
