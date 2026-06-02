# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Concerns
        # Renders classless structured inputs (single → hash via nest_one,
        # repeater → array via nest_many). Field/namespace work is delegated to
        # the form; this concern owns the structural markup.
        # @api private
        module RendersStructuredInputs
          extend ActiveSupport::Concern

          DEFAULT_REPEAT_LIMIT = 10

          private

          def render_structured_input(name)
            entry = resource_definition.defined_structured_inputs[name]
            options = entry[:options] || {}
            definition = structured_input_fields_definition(entry)
            fields = options[:fields] || definition.defined_inputs.keys
            repeat = options[:repeat]

            if repeat
              render_structured_repeater(name, definition, fields, repeat_limit(repeat))
            else
              render_structured_single(name, definition, fields)
            end
          end

          def structured_input_fields_definition(entry)
            return entry[:options][:using] if entry[:options]&.key?(:using)

            holder = Plutonium::Definition::StructuredInputs::FieldsDefinition.new
            entry[:block].call(holder)
            holder
          end

          def repeat_limit(repeat)
            repeat.is_a?(Integer) ? repeat : DEFAULT_REPEAT_LIMIT
          end

          # --- single -------------------------------------------------------

          def render_structured_single(name, definition, fields)
            value = indifferent(structured_input_value(name)) || {}
            value = {} unless value.is_a?(Hash) || value.respond_to?(:[])
            div(class: "col-span-full space-y-2 my-4") do
              h2(class: "text-lg font-semibold text-[var(--pu-text)]") { name.to_s.humanize }
              nest_one(name, as: name, object: value) do |nested|
                render_structured_fieldset(nested, definition, fields)
              end
            end
          end

          # --- repeater -----------------------------------------------------

          def render_structured_repeater(name, definition, fields, limit)
            rows = Array(structured_input_value(name)).map { |row| indifferent(row) }
            existing_collection = rows.presence || {NEW_RECORD: {}}
            div(
              class: "col-span-full space-y-2 my-4",
              data: {
                controller: "nested-resource-form-fields",
                nested_resource_form_fields_limit_value: limit
              }
            ) do
              h2(class: "text-lg font-semibold text-[var(--pu-text)]") { name.to_s.humanize }
              template data_nested_resource_form_fields_target: "template" do
                nest_many(name, as: name, collection: {NEW_RECORD: {}}, default: {NEW_RECORD: {}}, template: true) do |nested|
                  render_structured_fieldset(nested, definition, fields)
                end
              end
              nest_many(name, as: name, collection: existing_collection) do |nested|
                if nested.object.blank?
                  vanish { render_structured_fieldset(nested, definition, fields) }
                else
                  render_structured_fieldset(nested, definition, fields)
                end
              end
              div(data_nested_resource_form_fields_target: :target, hidden: true)
              render_structured_add_button(name)
            end
          end

          # --- helpers ------------------------------------------------------

          def structured_input_value(name)
            obj = object
            return nil unless obj.respond_to?(name)
            obj.public_send(name)
          end

          def indifferent(value)
            value.respond_to?(:with_indifferent_access) ? value.with_indifferent_access : value
          end

          def render_structured_fieldset(nested, definition, fields)
            # `data-new-record` makes the Stimulus controller's remove action
            # delete the row from the DOM (rather than looking for a `_destroy`
            # input, which classless structured inputs never render). Every row
            # is classless/unpersisted, so this is always set.
            fieldset(
              data_new_record: true,
              class: "nested-resource-form-fields border border-[var(--pu-border)] rounded-[var(--pu-radius-md)] p-4 space-y-4 relative"
            ) do
              div(class: "grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-4 grid-flow-row-dense") do
                fields.each { |input| render_simple_resource_field(input, definition, nested) }
              end
              render_structured_delete_button
            end
          end

          def render_structured_delete_button
            div(class: "flex items-center justify-end") do
              label(class: "inline-flex items-center text-md font-medium text-red-900 cursor-pointer") do
                plain "Delete"
                input(
                  type: :checkbox,
                  class: "w-4 h-4 ms-2 text-danger-600 bg-danger-100 border-danger-300 rounded cursor-pointer",
                  data_action: "nested-resource-form-fields#remove"
                )
              end
            end
          end

          def render_structured_add_button(name)
            div do
              button(
                type: :button,
                class: "inline-block",
                data: {action: "nested-resource-form-fields#add", nested_resource_form_fields_target: "addButton"}
              ) do
                span(class: "bg-secondary-700 text-white flex items-center justify-center px-4 py-1.5 text-sm font-medium rounded-lg") do
                  render Phlex::TablerIcons::Plus.new(class: "w-4 h-4 mr-1")
                  span { "Add #{name.to_s.singularize.humanize}" }
                end
              end
            end
          end
        end
      end
    end
  end
end
