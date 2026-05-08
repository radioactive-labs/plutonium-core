# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        # Phlexi form rendering the filter slideover body. Submits via GET
        # with `q[<filter>][<input>]=value` so the existing query object
        # parses values exactly as the legacy filter dropdown did. Hidden
        # fields preserve sort, scope and search state across applies.
        class FilterForm < Plutonium::UI::Form::Base
          attr_reader :query_object, :search_value, :search_param

          def initialize(*, query_object:, search_url:, search_param: :q, search_value: nil, attributes: {}, **opts, &)
            opts[:as] = :q
            opts[:method] = :get
            attributes = attributes.deep_merge(
              id: "filter-form",
              data: {turbo_frame: nil}
            )
            super(*, attributes:, **opts, &)
            @query_object = query_object
            @search_url = search_url
            @search_param = search_param
            @search_value = search_value
          end

          def form_class
            "flex-1 flex flex-col min-h-0"
          end

          def form_template
            render_header
            render_fields_region
            render_footer
            render_hidden_state
          end

          private

          def render_header
            div(class: "shrink-0 flex items-center justify-between gap-4 px-6 pt-5 pb-4 " \
                       "border-b border-[var(--pu-border)]") do
              h2(class: "text-lg font-semibold text-[var(--pu-text)]") { "Filters" }
              div(class: "flex items-center gap-1") do
                button(
                  type: "button",
                  class: "text-sm text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] px-2 py-1 rounded transition-colors",
                  data: {action: "filter-panel#clear"}
                ) { "Clear" }
                button(
                  type: "button",
                  class: "p-1.5 -m-1.5 text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)] rounded-md transition-colors",
                  data: {action: "filter-panel#close"},
                  "aria-label": "Close filters"
                ) do
                  render Phlex::TablerIcons::X.new(class: "w-5 h-5")
                end
              end
            end
          end

          def render_fields_region
            div(class: "flex-1 min-h-0 overflow-y-auto px-6 py-5 space-y-4") do
              query_object.filter_definitions.each do |filter_name, definition|
                nest_one filter_name do |nested|
                  inputs = definition.defined_inputs
                  has_multiple_inputs = inputs.size > 1
                  inputs.each do |input_name, _|
                    label = if has_multiple_inputs
                      "#{filter_name.to_s.humanize} (#{input_name.to_s.humanize.downcase})"
                    else
                      filter_name.to_s.humanize
                    end
                    render_filter_field(nested, definition, input_name, filter_label: label)
                  end
                end
              end
            end
          end

          def render_footer
            div(class: "shrink-0 px-6 py-3 border-t border-[var(--pu-border)] " \
                       "flex items-center justify-end gap-2") do
              render field(:submit).submit_button_tag(
                name: nil,
                class!: "pu-btn pu-btn-md pu-btn-primary"
              ) { "Apply" }
            end
          end

          # Hidden inputs preserve query state (sort, scope, search) so
          # applying a filter doesn't reset them.
          def render_hidden_state
            div(hidden: true) do
              if search_value.present?
                input(name: "#{search_param}[search]", value: search_value, type: :hidden, hidden: true)
              end
              render_sort_fields
              render_scope_fields
            end
          end

          def render_sort_fields
            field :sort_fields do |name|
              render name.input_array_tag do |array|
                render array.input_tag(type: :hidden, hidden: true)
              end
            end
            nest_one :sort_directions do |nested|
              query_object.sort_definitions.each do |filter_name, _|
                nested.field(filter_name) do |f|
                  render f.input_tag(type: :hidden, hidden: true)
                end
              end
            end
          end

          def render_scope_fields
            return if query_object.scope_definitions.blank?
            render field(:scope).input_tag(type: :hidden, hidden: true)
          end

          def render_filter_field(nested, resource_definition, name, filter_label: nil)
            input_definition = resource_definition.defined_inputs[name] || {}
            input_options = input_definition[:options] || {}
            field_options = resource_definition.defined_fields[name] ? resource_definition.defined_fields[name][:options].dup : {}

            tag = input_options[:as] || field_options[:as]
            tag_attributes = input_options.except(:wrapper, :as)

            tag_block = input_definition[:block] || ->(f) {
              tag ||= f.inferred_field_component
              f.send(:"#{tag}_tag", **tag_attributes, class: "w-full")
            }

            field_options = field_options.except(:as)

            # Explicitly thread the current param value as the field's
            # initial value. Phlexi *can* read it off the form's hash
            # record via `object[key]`, but going through `value:` is
            # unambiguous and avoids subtle differences between the
            # form's hash navigation and direct param reads.
            current_value = current_param_value(nested.key, name)

            div(class: "space-y-1.5") do
              label(class: "text-sm font-medium text-[var(--pu-text)]") { filter_label }
              nested.field(name, value: current_value, **field_options) do |f|
                f.placeholder(input_options[:include_blank] || "All") if input_options[:include_blank]
                render instance_exec(f, &tag_block)
              end
            end
          end

          def current_param_value(filter_name, input_name)
            helpers.params.dig(search_param, filter_name, input_name)
          end

          def form_action
            @search_url
          end
        end
      end
    end
  end
end
