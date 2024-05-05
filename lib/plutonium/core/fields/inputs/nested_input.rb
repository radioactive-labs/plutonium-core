module Plutonium
  module Core
    module Fields
      module Inputs
        class NestedInput < Base
          include Plutonium::Core::Definers::InputDefiner

          attr_reader :inputs, :resource_class

          def initialize(name, inputs:, resource_class:, allow_destroy:, update_only:, limit:, **user_options)
            @inputs = inputs
            @resource_class = resource_class
            @allow_destroy = allow_destroy
            @update_only = update_only
            @limit = limit

            super(name, **user_options)
          end

          def render(view_context, f, record, **opts)
            opts = options.deep_merge opts
            view_context.render_component :nested_resource_form_fields, form: f, **opts
          end

          def collect(params)
            attributes = params[param].each { |index, params| [index, defined_inputs.collect_all(params)] }.to_h

            {param => attributes}
          end

          private

          def param = :"#{name}_attributes"

          def input_options = {
            name:,
            resource_class:,
            allow_destroy: @allow_destroy,
            update_only: @update_only,
            limit: @limit,
            inputs: defined_inputs
          }

          def defined_inputs
            @defined_inputs ||= defined_inputs_for(*inputs)
          end
        end
      end
    end
  end
end
