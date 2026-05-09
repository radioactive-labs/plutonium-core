# frozen_string_literal: true

module Plutonium
  module UI
    module Grid
      # Renders a paginated collection of records as a responsive grid of
      # Card components. Mirrors the structure of Table::Resource (filter
      # panel, scopes pills, bulk actions, footer) so view-switching is
      # purely a render-shape change.
      class Resource < Plutonium::UI::Component::Base
        attr_reader :collection, :resource_fields, :resource_definition

        def initialize(collection, resource_fields:, resource_definition:)
          @collection = collection
          @resource_fields = resource_fields
          @resource_definition = resource_definition
        end

        def view_template
          div(data: filter_panel_controller_data) do
            render_scopes_pills
            render_toolbar

            div(data: bulk_actions_controller_data) do
              render_filter_pills
              render_bulk_actions_toolbar
              collection.empty? ? render_empty_card : render_grid
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
            search_url: request.path,
            search_value: params.dig(:q, :search) || params[:search],
            views: resource_definition.defined_views,
            current_view: :grid,
            view_cookie_name: Plutonium::UI::Page::Index.view_cookie_name(resource_class)
          )
        end

        def render_filter_pills
          TableFilterPills(query: current_query_object, total_count: pagy_instance&.count)
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

        def render_grid
          div(class: grid_class) do
            collection.each do |record|
              render Plutonium::UI::Grid::Card.new(record, resource_definition:)
            end
          end
        end

        # Default responsive: 1 / 2 / 3 / 4 columns at sm/md/lg/xl. When
        # the definition pins a fixed `grid_columns N`, use that on lg+ so
        # mobile still gets sensible single-column.
        def grid_class
          if resource_definition.defined_grid_columns
            n = resource_definition.defined_grid_columns
            "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-#{n} gap-4 mt-4"
          else
            "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4 mt-4"
          end
        end

        def bulk_actions
          @bulk_actions ||= resource_definition.defined_actions
            .select { |k, a| a.bulk_action? }
            .values
        end

        def bulk_actions_controller_data
          {
            controller: "bulk-actions",
            bulk_actions_has_actions_value: bulk_actions.any?
          }
        end

        def filter_panel_controller_data
          {controller: "filter-panel"}
        end

        def render_filter_slideover
          div(
            class: "fixed inset-0 z-40 bg-black/40 opacity-0 pointer-events-none " \
                   "transition-opacity duration-200 " \
                   "data-[open]:opacity-100 data-[open]:pointer-events-auto",
            data: {filter_panel_target: "backdrop", action: "click->filter-panel#close"}
          )
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
              search_url: request.path,
              search_value: params.dig(:q, :search) || params[:search]
            )
          end
        end

        def filter_form_values
          raw = params[:q]
          return {} unless raw
          hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
          hash.deep_symbolize_keys.except(:search, :scope, :sort_fields, :sort_directions)
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
