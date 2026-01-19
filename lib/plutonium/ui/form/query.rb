# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Query < Base
        attr_reader :query_object

        def initialize(*, query_object:, page_size:, attributes: {}, **options, &)
          options[:as] = :q
          options[:method] = :get
          attributes = mix(attributes.deep_merge(
            id: :search_form,
            controller: "form",
            data: {controller: "form", turbo_frame: nil}
          ))
          super(*, attributes:, **options, &)

          @query_object = query_object
          @page_size = page_size
        end

        def form_class
          "mb-4"
        end

        def form_template
          render_fields
        end

        private

        def render_fields
          has_search = query_object.search_filter.present?
          has_filters = query_object.filter_definitions.present?

          if has_search || has_filters
            div(class: "flex items-center gap-3") do
              # Search takes remaining space
              if has_search
                render_search_field
              else
                div(class: "flex-1") # Spacer when no search
              end
              render_filter_button if has_filters
            end
          end

          # Hidden fields for sorting, scope, etc.
          div(hidden: true) do
            input(name: "limit", value: @page_size, type: :hidden, hidden: true) if @page_size
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
            query_object.sort_definitions.each do |filter_name, definition|
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

        def render_search_field
          search_query = query_object.search_query
          div(class: "relative flex-1 min-w-0") do
            div(class: "absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none") do
              render Phlex::TablerIcons::Search.new(class: "w-5 h-5 text-[var(--pu-text-muted)]")
            end
            render field(:search, value: search_query)
              .placeholder("Search...")
              .input_tag(
                value: search_query,
                class: "pu-input pu-input-icon-left w-full",
                data: {action: "form#submit", turbo_permanent: true}
              )
          end
        end

        def render_filter_button
          active_count = count_active_filters

          div(
            class: "relative",
            data: {controller: "resource-drop-down", resource_drop_down_placement_value: "left-start"}
          ) do
            # Filter button (trigger)
            button(
              type: "button",
              class: "pu-btn pu-btn-secondary px-4 py-3 text-base",
              data: {resource_drop_down_target: "trigger"}
            ) do
              render Phlex::TablerIcons::Filter.new(class: "w-4 h-4 inline-block align-text-bottom")
              plain " Filters"
              if active_count > 0
                plain " "
                span(class: "inline-flex items-center justify-center w-5 h-5 text-xs font-semibold rounded-full text-gray-800 bg-white") do
                  plain active_count.to_s
                end
              end
            end

            # Filter panel (dropdown menu)
            # Mobile: fullscreen (override Popper with !important)
            # Desktop: Popper positions the dropdown
            div(
              class: "hidden z-[100] bg-[var(--pu-surface)] shadow-lg flex flex-col " \
                     "max-md:!fixed max-md:!inset-0 max-md:!transform-none " \
                     "md:w-80 md:max-h-[70vh] md:border md:border-[var(--pu-border)] md:rounded-[var(--pu-radius-lg)]",
              data: {resource_drop_down_target: "menu"},
              aria_hidden: "true"
            ) do
              render_filter_panel
            end
          end
        end

        def render_filter_panel
          # Sticky header
          div(class: "sticky top-0 z-10 flex items-center justify-between p-4 bg-[var(--pu-surface)] border-b border-[var(--pu-border)]") do
            div(class: "flex items-center gap-3") do
              # Close button (mobile only)
              button(
                type: "button",
                class: "md:hidden p-1 text-[var(--pu-text-muted)] hover:text-[var(--pu-text)]",
                data: {action: "resource-drop-down#hide"}
              ) do
                render Phlex::TablerIcons::X.new(class: "w-5 h-5")
              end
              span(class: "text-sm font-semibold text-[var(--pu-text)]") { "Filters" }
            end
            render field(:reset).submit_button_tag(
              name: nil,
              type: :reset,
              class!: "text-sm text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] transition-colors"
            ) { "Clear all" }
          end

          # Scrollable filter fields
          div(class: "p-4 overflow-y-auto flex-1 space-y-4") do
            query_object.filter_definitions.each do |filter_name, definition|
              nest_one filter_name do |nested|
                inputs = definition.defined_inputs
                has_multiple_inputs = inputs.size > 1
                inputs.each do |input_name, _|
                  # For multi-input filters (like date range), include the input name in the label
                  label = if has_multiple_inputs
                    "#{filter_name.to_s.humanize} (#{input_name.to_s.humanize.downcase})"
                  else
                    filter_name.to_s.humanize
                  end
                  render_filter_field nested, definition, input_name, filter_label: label
                end
              end
            end
          end

          # Sticky footer
          div(class: "sticky bottom-0 z-10 p-4 bg-[var(--pu-surface)] border-t border-[var(--pu-border)]") do
            render field(:submit).submit_button_tag(
              name: nil,
              class!: "pu-btn pu-btn-md pu-btn-primary w-full"
            ) { "Apply Filters" }
          end
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

          # Render with label
          div(class: "space-y-1.5") do
            label(class: "text-sm font-medium text-[var(--pu-text)]") { filter_label }
            nested.field(name, **field_options) do |f|
              # Set placeholder for blank option text in selects
              f.placeholder(input_options[:include_blank] || "All") if input_options[:include_blank]
              render instance_exec(f, &tag_block)
            end
          end
        end

        def count_active_filters
          count = 0
          query_object.filter_definitions.each do |filter_name, _|
            filter_params = helpers.params.dig(:q, filter_name)
            next unless filter_params.is_a?(Hash) || filter_params.is_a?(ActionController::Parameters)

            filter_params.each_value do |v|
              count += 1 if v.present?
            end
          end
          count
        end

        def form_action
          nil
        end
      end
    end
  end
end
