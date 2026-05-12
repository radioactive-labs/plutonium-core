# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      class Resource < Plutonium::UI::Component::Base
        attr_reader :collection, :resource_fields, :resource_definition

        def initialize(collection, resource_fields:, resource_definition:)
          @collection = collection
          @resource_fields = resource_fields
          @resource_definition = resource_definition
        end

        def view_template
          # filter-panel controller wraps everything so the toolbar's
          # filter button AND the FilterPills "+ Filter" pill (a sibling
          # below the toolbar) share the same controller scope and can
          # toggle the slideover rendered alongside them.
          div(data: filter_panel_controller_data) do
            render_scopes_pills
            render_toolbar

            div(data: bulk_actions_controller_data) do
              render_filter_pills
              render_bulk_actions_toolbar
              collection.empty? ? render_empty_card : render_table
            end

            render_filter_slideover if current_query_object.filter_definitions.present?
          end

          render_footer
        end

        private

        def render_scopes_pills
          TableScopesPills() if current_query_object.scope_definitions.any?
        end

        def render_toolbar
          TableToolbar(
            query: current_query_object,
            search_url: current_search_url,
            search_value: params.dig(:q, :search) || params[:search],
            views: resource_definition.defined_index_views,
            current_view: :table,
            view_cookie_name: Plutonium::UI::Page::Index.view_cookie_name(resource_class),
            view_cookie_path: Plutonium::UI::Page::Index.view_cookie_path(request)
          )
        end

        def render_filter_pills
          TableFilterPills(query: current_query_object, total_count: pagy_instance&.count)
        end

        def current_search_url
          request.path
        end

        def render_bulk_actions_toolbar
          return unless bulk_actions.any?
          BulkActionsToolbar(bulk_actions:)
        end

        def render_empty_card
          EmptyCard("No #{resource_name_plural(resource_class).downcase} available") {
            action = resource_definition.defined_actions[:new]
            if action&.permitted_by?(current_policy)
              url = route_options_to_url(action.route_options, resource_class)
              ActionButton(action, url:)
            end
          }
        end

        def render_table
          render Plutonium::UI::Table::Base.new(collection) do |table|
            # Selection column only renders when bulk actions exist —
            # the server already knows, so no JS toggle is needed.
            # Use :_selection as column key to avoid conflicts with field columns;
            # value_key defaults to model's primary_key.
            if bulk_actions.any?
              table.selection_column :_selection,
                bulk_actions:,
                policy_resolver: ->(record) { policy_for(record:) }
            end

            @resource_fields.each do |name|
              field_options = resource_definition.defined_fields[name] ? resource_definition.defined_fields[name][:options].dup : {}

              display_definition = resource_definition.defined_displays[name] || {}
              display_options = display_definition[:options] || {}

              column_definition = resource_definition.defined_columns[name] || {}
              column_options = column_definition[:options] || {}

              # Check for conditional rendering
              condition = column_options[:condition]
              conditionally_hidden = condition && !instance_exec(&condition)
              next if conditionally_hidden

              tag = column_options[:as] || display_definition[:as] || field_options[:as]

              # Extract field-level options from display_options and column_options
              # These are Phlexi field options that should NOT be passed to the tag builder
              field_level_keys = [:label, :description, :placeholder]
              display_tag_attributes = display_options.except(:wrapper, :as, :condition, *field_level_keys)
              column_tag_attributes = column_options.except(:wrapper, :as, :align, :condition, *field_level_keys)
              tag_attributes = display_tag_attributes.merge(column_tag_attributes)
              tag_block = if column_definition[:block]
                # User-provided blocks receive the raw record for convenience
                user_block = column_definition[:block]
                ->(wrapped_object, _key) { user_block.call(wrapped_object.unwrapped) }
              else
                ->(wrapped_object, key) {
                  f = wrapped_object.field(key)
                  tag ||= f.inferred_field_component
                  f.send(:"#{tag}_tag", **tag_attributes)
                }
              end

              # For table columns, only extract column-level options (label and align)
              # Field-level options like description and placeholder don't make sense in table cells
              field_options = field_options.except(:condition).merge(**column_options.slice(:align, :label))
              table.column name,
                **field_options,
                sort_params: current_query_object.sort_params_for(name),
                &tag_block
            end

            table.actions do |wrapped_object|
              record = wrapped_object.unwrapped
              policy = policy_for(record:)

              actions = resource_definition.defined_actions
                .select { |k, a| a.collection_record_action? && policy.allowed_to?(:"#{k}?") }
                .values

              primary_actions = actions.select { |a| a.category.primary? }.sort_by(&:position)
              dropdown_actions = actions.reject { |a| a.category.primary? }.sort_by(&:position)

              div(class: "flex items-center gap-1") do
                # Primary actions as buttons. The :show action is also
                # tagged so the `row-click` controller on the <tr> can
                # delegate row-body clicks to it.
                primary_actions.each do |action|
                  url = route_options_to_url(action.route_options, record)
                  data = (action.name == :show) ? {row_click_target: "show"} : {}
                  ActionButton(action, url:, variant: :table, data: data)
                end

                # Secondary/danger actions in dropdown
                if dropdown_actions.any?
                  RowActionsDropdown(actions: dropdown_actions, record:)
                end
              end
            end
          end
        end

        def bulk_actions
          @bulk_actions ||= resource_definition.defined_actions
            .select { |k, a| a.bulk_action? }
            .values
        end

        def filter_panel_controller_data
          {controller: "filter-panel"}
        end

        # Hash of the current `q` params reduced to filter values only —
        # used as the FilterForm's record so Phlexi prefills inputs from
        # the URL (it reads values via `object[key]` for Hashes).
        def filter_form_values
          raw = params[:q]
          return {} unless raw

          hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
          hash = hash.deep_symbolize_keys
          hash.except(:search, :scope, :sort_fields, :sort_directions)
        end

        def render_filter_slideover
          # Backdrop — click-to-close; transparent until panel opens.
          div(
            class: "fixed inset-0 z-40 bg-black/40 opacity-0 pointer-events-none " \
                   "transition-opacity duration-200 " \
                   "data-[open]:opacity-100 data-[open]:pointer-events-auto",
            data: {filter_panel_target: "backdrop", action: "click->filter-panel#close"}
          )

          # Panel — fixed slideover from the right; the form inside owns
          # its scroll region and pinned action strip.
          aside(
            class: "fixed top-0 right-0 bottom-0 z-50 w-full sm:w-[420px] max-w-full " \
                   "bg-[var(--pu-surface)] border-l border-[var(--pu-border)] " \
                   "translate-x-full transition-transform duration-300 ease-out " \
                   "data-[open]:translate-x-0 " \
                   "flex flex-col",
            role: "dialog",
            aria: {label: "Filters", hidden: "true", modal: "true"},
            data: {filter_panel_target: "panel"}
          ) do
            render Plutonium::UI::Table::Components::FilterForm.new(
              filter_form_values,
              query_object: current_query_object,
              search_url: current_search_url,
              search_value: params.dig(:q, :search) || params[:search]
            )
          end
        end

        def bulk_actions_controller_data
          {controller: "bulk-actions"}
        end

        def render_footer
          div(class: "lg:sticky bottom-[-2px] mt-1 p-4 pb-6 w-full z-30 bg-[var(--pu-body)]") {
            TableInfo(pagy_instance)
            TablePagination(pagy_instance)
          }
        end
      end
    end
  end
end
