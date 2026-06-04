# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Concerns
        # Handles rendering of nested resource fields in forms
        # TODO: further decompose this into components
        # @api private
        module RendersNestedResourceFields
          extend ActiveSupport::Concern

          DEFAULT_NESTED_LIMIT = RepeaterFieldStyles::DEFAULT_LIMIT
          NESTED_OPTION_KEYS = [:allow_destroy, :update_only, :macro, :class].freeze
          SINGULAR_MACROS = %i[belongs_to has_one].freeze

          class NestedInputsDefinition
            include Plutonium::Definition::DefineableProps

            defineable_props :field, :input
          end

          class NestedFieldContext
            attr_reader :name, :definition, :options, :permitted_fields

            def initialize(name:, definition:, resource_class:, resource_definition:, object_class:)
              @name = name
              @definition = definition
              @resource_definition = resource_definition
              @resource_class = resource_class
              @options = build_options
              @permitted_fields = build_permitted_fields
              @object_class = object_class
            end

            def nested_attribute_options
              @nested_attribute_options ||= @resource_class.all_nested_attributes_options[@name] || {}
            end

            def nested_fields_input_param
              @options[:as] || :"#{@name}_attributes"
            end

            def nested_fields_multiple?
              @options[:multiple]
            end

            def blank_object
              (@object_class || nested_attribute_options[:class])&.new
            end

            private

            def build_options
              options = @resource_definition.defined_nested_inputs[@name][:options].dup || {}
              merge_nested_fields_options(options)
              set_nested_fields_limits(options)
              options
            end

            def merge_nested_fields_options(options)
              NESTED_OPTION_KEYS.each do |key|
                options.fetch(key) { options[key] = nested_attribute_options[key] }
              end
            end

            def set_nested_fields_limits(options)
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

          # Template object for new nested records

          private

          # Renders a nested resource field with associated inputs
          # @param [Symbol] name The name of the nested resource field
          # @raise [ArgumentError] if the nested input definition is missing required configuration
          def render_nested_resource_field(name)
            nested_input_definition = resource_definition.defined_nested_inputs[name]
            condition = nested_input_definition[:options]&.fetch(:condition, nil)
            if condition && !instance_exec(&condition)
              return
            end

            context = NestedFieldContext.new(
              name: name,
              definition: build_nested_fields_definition(name),
              resource_class: resource_class,
              resource_definition: resource_definition,
              object_class: nested_input_definition[:options]&.fetch(:object_class, nil)
            )

            render_nested_field_container(context) do
              render_nested_field_header(context)
              render_nested_field_content(context)
              render_nested_fields_add_button(context)
            end
          end

          def build_nested_fields_definition(name)
            nested_input_definition = resource_definition.defined_nested_inputs[name]

            if nested_input_definition[:options]&.fetch(:using, nil)
              nested_input_definition[:options][:using]
            elsif nested_input_definition[:block]
              build_nested_fields_definition_from_block(nested_input_definition[:block])
            else
              raise_missing_nested_definition_error(name)
            end
          end

          def build_nested_fields_definition_from_block(block)
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
              h2(class: "text-lg font-semibold text-[var(--pu-text)]") { context.name.to_s.humanize }
              render_nested_fields_header_description(context.options[:description]) if context.options[:description]
            end
          end

          def render_nested_fields_header_description(description)
            p(class: "text-md font-normal text-[var(--pu-text-muted)]") { description }
          end

          def render_nested_field_content(context)
            if context.nested_fields_multiple?
              render_multiple_nested_fields(context)
            else
              render_single_nested_field(context)
            end

            div(data_nested_resource_form_fields_target: :target, hidden: true)
          end

          def render_multiple_nested_fields(context)
            nesting_method = :nest_many
            options = {default: {NEW_RECORD: context.blank_object}}
            render_template_for_nested_fields(context, options.merge(collection: {NEW_RECORD: context.blank_object}), nesting_method:)
            render_existing_nested_fields(context, options, nesting_method:)
          end

          def render_single_nested_field(context)
            nesting_method = :nest_one
            options = {default: context.blank_object}
            render_template_for_nested_fields(context, options.merge(object: context.blank_object), nesting_method:)
            render_existing_nested_fields(context, options, nesting_method:)
          end

          def render_template_for_nested_fields(context, options, nesting_method:)
            template data_nested_resource_form_fields_target: "template" do
              send(nesting_method, context.name, as: context.nested_fields_input_param, **options, template: true) do |nested|
                render_nested_fields_fieldset(nested, context)
              end
            end
          end

          def render_existing_nested_fields(context, options, nesting_method:)
            send(nesting_method, context.name, as: context.nested_fields_input_param, **options) do |nested|
              render_nested_fields_fieldset(nested, context)
            end
          end

          def render_nested_fields_fieldset(nested, context)
            removable = !nested.object&.persisted? || context.options[:allow_destroy]
            fieldset(
              data_new_record: !nested.object&.persisted?,
              class: RepeaterFieldStyles::FIELDSET_CLASS
            ) do
              # Content is wrapped so the controller can hide it (and reveal the
              # removed bar) on remove without disturbing the row itself, leaving
              # the hidden _destroy field in place to submit the deletion.
              div(data_nested_content: "") do
                render_nested_fields_fieldset_content(nested, context)
                render_repeater_remove_button(action: "nested-resource-form-fields#remove") if removable
              end
              if removable
                render_repeater_removed_bar(
                  restore_action: "nested-resource-form-fields#restore",
                  data_nested_removed: ""
                )
              end
            end
          end

          def render_nested_fields_fieldset_content(nested, context)
            div(class: RepeaterFieldStyles::FIELD_GRID_CLASS) do
              render_nested_fields_hidden_fields(nested, context)
              render_nested_fields_visible_fields(nested, context)
            end
          end

          def render_nested_fields_hidden_fields(nested, context)
            if !context.options[:update_only] && context.options[:class]&.respond_to?(:primary_key)
              render nested.field(context.options[:class].primary_key).hidden_tag
            end
            render nested.field(:_destroy).hidden_tag if context.options[:allow_destroy]
          end

          def render_nested_fields_visible_fields(nested, context)
            context.permitted_fields.each do |input|
              render_simple_resource_field(input, context.definition, nested)
            end
          end

          def render_nested_fields_add_button(context)
            div do
              button(
                type: :button,
                class: "inline-block",
                data: {
                  action: "nested-resource-form-fields#add",
                  nested_resource_form_fields_target: "addButton"
                }
              ) do
                render_nested_fields_add_button_content(context.name)
              end
            end
          end

          def render_nested_fields_add_button_content(name)
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
                definition.input :city
                definition.input :country
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
