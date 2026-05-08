# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        # Modern index toolbar combining view switcher, filter/group controls,
        # inline search, and column config / overflow icon buttons into a single
        # tight strip rendered above the table when shell == :modern.
        class Toolbar < Plutonium::UI::Component::Base
          def initialize(query:, search_url:, search_param: :q, search_value: nil)
            @query = query
            @search_url = search_url
            @search_param = search_param
            @search_value = search_value
          end

          def view_template
            div(class: "flex items-center gap-2 px-4 py-2 border-b border-[var(--pu-border)] bg-[var(--pu-surface-alt)]") do
              # 1. View switcher
              render ViewSwitcher.new

              # 2. Vertical divider
              render_divider

              # 3. Filter button
              render_filter_button

              # 4. Group button (disabled placeholder)
              render_group_button

              # 5. Spacer
              div(class: "flex-1")

              # 6. Search input
              render_search

              # 7. Vertical divider
              render_divider

              # 8. Column config button (disabled placeholder)
              render_column_config_button

              # 9. Overflow button (disabled placeholder)
              render_overflow_button
            end
          end

          private

          def render_divider
            div(class: "w-px h-5 bg-[var(--pu-border)]")
          end

          def render_filter_button
            button(
              type: "button",
              class: "pu-btn pu-btn-outline pu-btn-sm",
              data: {action: "click->filter-panel#toggle"}
            ) do
              render Phlex::TablerIcons::AdjustmentsHorizontal.new(class: "w-4 h-4 shrink-0")
              span { "Filter" }
            end
          end

          def render_group_button
            button(
              type: "button",
              class: "pu-btn pu-btn-outline pu-btn-sm disabled cursor-not-allowed opacity-60",
              disabled: true,
              title: "Coming soon"
            ) do
              render Phlex::TablerIcons::Stack2.new(class: "w-4 h-4 shrink-0")
              span { "Group" }
            end
          end

          def render_search
            form(method: :get, action: @search_url) do
              div(class: "relative") do
                div(class: "absolute inset-y-0 left-0 flex items-center pl-2 pointer-events-none") do
                  render Phlex::TablerIcons::Search.new(class: "w-4 h-4 text-[var(--pu-text-muted)]")
                end
                input(
                  type: "search",
                  name: "#{@search_param}[search]",
                  value: @search_value,
                  placeholder: "Search...",
                  class: "pu-input pu-input-toolbar pu-input-icon-left w-[220px]"
                )
              end
            end
          end

          def render_column_config_button
            button(
              type: "button",
              class: "pu-btn pu-btn-outline pu-btn-sm disabled cursor-not-allowed opacity-60",
              disabled: true,
              aria: {label: "Configure columns"},
              title: "Coming soon"
            ) do
              render Phlex::TablerIcons::Columns3.new(class: "w-4 h-4 shrink-0")
            end
          end

          def render_overflow_button
            button(
              type: "button",
              class: "pu-btn pu-btn-outline pu-btn-sm disabled cursor-not-allowed opacity-60",
              disabled: true,
              aria: {label: "More options"},
              title: "Coming soon"
            ) do
              render Phlex::TablerIcons::Dots.new(class: "w-4 h-4 shrink-0")
            end
          end
        end
      end
    end
  end
end
