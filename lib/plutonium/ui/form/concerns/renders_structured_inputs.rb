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
            repeat.is_a?(Integer) ? repeat : RepeaterFieldStyles::DEFAULT_LIMIT
          end

          # --- single -------------------------------------------------------

          def render_structured_single(name, definition, fields)
            raw = structured_input_value(name)
            value = raw.is_a?(Hash) ? raw.with_indifferent_access : {}
            div(class: "col-span-full space-y-2 my-4") do
              h2(class: "text-lg font-semibold text-[var(--pu-text)]") { name.to_s.humanize }
              nest_one(name, as: name, object: value) do |nested|
                render_structured_fieldset(nested, definition, fields, removable: false)
              end
            end
          end

          # --- repeater -----------------------------------------------------

          def render_structured_repeater(name, definition, fields, limit)
            rows = Array(structured_input_value(name)).map { |row| row.is_a?(Hash) ? row.with_indifferent_access : row }
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
                  render_structured_fieldset(nested, definition, fields, removable: true)
                end
              end
              nest_many(name, as: name, collection: existing_collection) do |nested|
                if nested.object.blank?
                  vanish { render_structured_fieldset(nested, definition, fields, removable: true) }
                else
                  render_structured_fieldset(nested, definition, fields, removable: true)
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

          # Single source of truth shared with RendersNestedResourceFields.
          FIELDSET_CLASS = RepeaterFieldStyles::FIELDSET_CLASS
          FIELD_GRID_CLASS = RepeaterFieldStyles::FIELD_GRID_CLASS

          # @param removable [Boolean] repeater rows are removable; a single
          #   structured input is the one-and-only object, so it is not.
          def render_structured_fieldset(nested, definition, fields, removable:)
            unless removable
              return fieldset(class: FIELDSET_CLASS) do
                div(class: FIELD_GRID_CLASS) do
                  fields.each { |input| render_simple_resource_field(input, definition, nested) }
                end
              end
            end

            # Removable rows soft-delete by DISABLING the inner fieldset: a
            # disabled <fieldset> is omitted from submission, so the server just
            # receives the payload without this row and rebuilds the JSON column
            # from what it gets (no _destroy marker). The row stays in the DOM,
            # collapsed to a "Removed — Restore" bar, so it can be restored.
            div(data_controller: "structured-input-row", class: FIELDSET_CLASS) do
              fieldset(data_structured_input_row_target: "content", class: "space-y-4 border-0 p-0 m-0") do
                div(class: FIELD_GRID_CLASS) do
                  fields.each { |input| render_simple_resource_field(input, definition, nested) }
                end
                render_structured_remove_button
              end
              render_structured_removed_bar
            end
          end

          def render_structured_remove_button
            div(class: "flex items-center justify-end") do
              button(
                type: :button,
                class: "inline-flex items-center gap-1 px-3 py-1.5 text-sm font-medium rounded-lg cursor-pointer " \
                       "text-danger-700 hover:bg-danger-50 dark:text-danger-400 dark:hover:bg-danger-950/30 " \
                       "focus:outline-none focus:ring-4 focus:ring-danger-200 dark:focus:ring-danger-900",
                data_action: "structured-input-row#remove"
              ) do
                render Phlex::TablerIcons::Trash.new(class: "w-4 h-4")
                span { "Remove" }
              end
            end
          end

          # Compact bar shown in place of the row once it's marked for removal.
          def render_structured_removed_bar
            div(
              data_structured_input_row_target: "removed",
              hidden: true,
              class: "flex items-center justify-between gap-3 text-sm text-[var(--pu-text-muted)]"
            ) do
              span(class: "italic") { "Removed" }
              button(
                type: :button,
                class: "inline-flex items-center gap-1 px-3 py-1.5 text-sm font-medium rounded-lg cursor-pointer " \
                       "text-secondary-700 hover:bg-secondary-50 dark:text-secondary-300 dark:hover:bg-secondary-900/30 " \
                       "focus:outline-none focus:ring-4 focus:ring-secondary-200 dark:focus:ring-secondary-900",
                data_action: "structured-input-row#restore"
              ) do
                render Phlex::TablerIcons::ArrowBackUp.new(class: "w-4 h-4")
                span { "Restore" }
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
