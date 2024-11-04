# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Concerns
        # Handles rendering of nested resource fields in forms
        # @api private
        module RendersNestedResourceFields
          extend ActiveSupport::Concern

          DEFAULT_NESTED_LIMIT = 10
          NESTED_OPTION_KEYS = [:allow_destroy, :update_only, :macro, :class].freeze
          SINGULAR_MACROS = %i[belongs_to has_one].freeze

          class NestedInputsDefinition
            include Plutonium::Definition::DefineableProps

            defineable_props :field, :input
          end

          # Template object for new nested records
          class NotPersisted
            def persisted?
              false
            end
          end

          private

          # Renders a nested resource field with associated inputs
          # @param [Symbol] name The name of the nested resource field
          # @raise [ArgumentError] if the nested input definition is missing required configuration
          def render_nested_resource_field(name)
            context = NestedFieldContext.new(
              name: name,
              definition: build_nested_definition(name),
              resource_class: resource_class,
              resource_definition: resource_definition
            )

            render_nested_field_container(context) do
              render_nested_field_header(context)
              render_nested_field_content(context)
              render_nested_add_button(context)
            end
          end

          private

          class NestedFieldContext
            attr_reader :name, :definition, :options, :permitted_fields

            def initialize(name:, definition:, resource_class:, resource_definition:)
              @name = name
              @definition = definition
              @resource_definition = resource_definition
              @resource_class = resource_class
              @options = build_options
              @permitted_fields = build_permitted_fields
            end

            def nested_attribute_options
              @nested_attribute_options ||= @resource_class.all_nested_attributes_options[@name] || {}
            end

            def nested_input_param
              @options[:as] || :"#{@name}_attributes"
            end

            def multiple?
              @options[:multiple]
            end

            private

            def build_options
              options = @resource_definition.defined_nested_inputs[@name][:options].dup || {}
              merge_nested_options(options)
              set_nested_limits(options)
              options
            end

            def merge_nested_options(options)
              NESTED_OPTION_KEYS.each do |key|
                options.fetch(key) { options[key] = nested_attribute_options[key] }
              end
            end

            def set_nested_limits(options)
              options.fetch(:limit) do
                options[:limit] = if SINGULAR_MACROS.include?(nested_attribute_options[:macro])
                  1
                else
                  nested_attribute_options[:limit] || DEFAULT_NESTED_LIMIT
                end
              end

              options.fetch(:multiple) do
                options[:multiple] = !SINGULAR_MACROS.include?(nested_attribute_options[:macro])
              end
            end

            def build_permitted_fields
              @options[:fields] || @definition.defined_inputs.keys
            end
          end

          def build_nested_definition(name)
            nested_input_definition = resource_definition.defined_nested_inputs[name]

            if nested_input_definition[:options]&.fetch(:using, nil)
              nested_input_definition[:options][:using]
            elsif nested_input_definition[:block]
              build_definition_from_block(nested_input_definition[:block])
            else
              raise_missing_nested_definition_error(name)
            end
          end

          def build_definition_from_block(block)
            definition = NestedInputsDefinition.new
            block.call(definition)
            definition
          end

          def render_nested_field_container(context, &)
            div(
              class: "col-span-full space-y-2 my-4",
              data: {
                controller: "nested-resource-form-fields",
                nested_resource_form_fields_limit_value: context.options[:limit]
              },
              &
            )
          end

          def render_nested_field_header(context)
            div do
              h2(class: "text-lg font-semibold text-gray-900 dark:text-white") { context.name.to_s.humanize }
              render_description(context.options[:description]) if context.options[:description]
            end
          end

          def render_description(description)
            p(class: "text-md font-normal text-gray-500 dark:text-gray-400") { description }
          end

          def render_nested_field_content(context)
            if context.multiple?
              render_multiple_nested_fields(context)
            else
              render_single_nested_field(context)
            end

            div(data_nested_resource_form_fields_target: :target, hidden: true)
          end

          def render_multiple_nested_fields(context)
            render_template_for_nested_fields(context, collection: {NEW_RECORD: NotPersisted.new})
            render_existing_nested_fields(context)
          end

          def render_single_nested_field(context)
            render_template_for_nested_fields(context, object: NotPersisted.new)
            render_existing_nested_fields(context, single: true)
          end

          def render_template_for_nested_fields(context, field_options)
            template_tag data_nested_resource_form_fields_target: "template" do
              nesting_method = field_options[:collection] ? :nest_many : :nest_one
              send(nesting_method, context.name, as: context.nested_input_param, template: true, **field_options) do |nested|
                render_fieldset(nested, context)
              end
            end
          end

          def render_existing_nested_fields(context, single: false)
            nesting_method = single ? :nest_one : :nest_many
            send(nesting_method, context.name, as: context.nested_input_param) do |nested|
              render_fieldset(nested, context)
            end
          end

          def render_fieldset(nested, context)
            fieldset(
              data_new_record: !nested.object&.persisted?,
              class: "nested-resource-form-fields border border-gray-200 dark:border-gray-700 rounded-lg p-4 space-y-4 relative"
            ) do
              render_fieldset_content(nested, context)
              render_delete_button(nested, context.options)
            end
          end

          def render_fieldset_content(nested, context)
            div(class: "grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-4 grid-flow-row-dense") do
              render_hidden_fields(nested, context)
              render_input_fields(nested, context)
            end
          end

          def render_hidden_fields(nested, context)
            if !context.options[:update_only] && context.options[:class]&.respond_to?(:primary_key)
              render nested.field(context.options[:class].primary_key).hidden_tag
            end
            render nested.field(:_destroy).hidden_tag if context.options[:allow_destroy]
          end

          def render_input_fields(nested, context)
            context.permitted_fields.each do |input|
              render_simple_resource_field(input, context.definition, nested)
            end
          end

          def render_delete_button(nested, options)
            return unless !nested.object&.persisted? || options[:allow_destroy]

            render_delete_button_content
          end

          def render_delete_button_content
            div(class: "flex items-center justify-end") do
              label(class: "inline-flex items-center text-md font-medium text-red-900 cursor-pointer") do
                plain "Delete"
                render_delete_checkbox
              end
            end
          end

          def render_delete_checkbox
            input(
              type: :checkbox,
              class: "w-4 h-4 ms-2 text-red-600 bg-red-100 border-red-300 rounded focus:ring-red-500 dark:focus:ring-red-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600 cursor-pointer",
              data_action: "nested-resource-form-fields#remove"
            )
          end

          def render_nested_add_button(context)
            div do
              button(
                type: :button,
                class: "inline-block",
                data: {
                  action: "nested-resource-form-fields#add",
                  nested_resource_form_fields_target: "addButton"
                }
              ) do
                render_add_button_content(context.name)
              end
            end
          end

          def render_add_button_content(name)
            span(class: "bg-secondary-700 text-white hover:bg-secondary-800 focus:ring-secondary-300 dark:bg-secondary-600 dark:hover:bg-secondary-700 dark:focus:ring-secondary-800 flex items-center justify-center px-4 py-1.5 text-sm font-medium rounded-lg focus:outline-none focus:ring-4") do
              render Phlex::TablerIcons::Plus.new(class: "w-4 h-4 mr-1")
              span { "Add #{name.to_s.singularize.humanize}" }
            end
          end

          def raise_missing_nested_definition_error(name)
            raise ArgumentError, %(
              `nested_input :#{name}` is missing a definition

              you can either pass in a block:
              ```ruby
              nested_input :#{name} do |definition|
                input :city
                input :country
              end
              ```

              or pass in options:
              ```ruby
              nested_input :#{name}, using: #{name.to_s.classify}Definition, fields: %i[city country]
              ```
            )
          end
        end
      end
    end
  end
end
