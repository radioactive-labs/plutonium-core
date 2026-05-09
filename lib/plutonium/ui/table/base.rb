# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      class Base < Phlexi::Table::Base
        include Plutonium::UI::Component::Behaviour

        # Make every body row a row-click candidate. The controller
        # delegates to whatever element inside the row is tagged
        # `data-row-click-target="show"` (typically the show action
        # button). Rows without such a target become a no-op — no
        # special-casing needed in this layer.
        def table_body_row_attributes(wrapped_object)
          super.merge(data: {controller: "row-click", action: "click->row-click#click"})
        end

        # Use custom SelectionColumn with Stimulus data attributes
        class SelectionColumn < Plutonium::UI::Table::Components::SelectionColumn; end

        class Display < Plutonium::UI::Display::Base
          class Builder < Builder
            def attachment_tag(**, &)
              create_component(Plutonium::UI::Table::Components::Attachment, :attachment, **, &)
            end
          end
        end

        # Override DataColumn to use our enhanced SortableHeaderCell
        class DataColumn < Phlexi::Table::Components::DataColumn
          def header_cell
            SortableHeaderCell.new(label, sort_params:)
          end
        end

        # Enhanced sortable header cell with:
        # - plain click → replace sort (single column); shift-click → multi-sort
        # - direction indicator (↑/↓) with priority badge when multi-sort active
        # - ⋯ column menu with Clear sort + disabled placeholders
        class SortableHeaderCell < Phlexi::Table::Components::SortableHeaderCell
          def view_template
            if !sort_params
              div(class: themed(:header_cell_content_wrapper)) { plain label_text }
              return
            end

            div(class: themed(:header_cell_sort_wrapper), data: {controller: "table-header"}) do
              render_sort_link
              render_column_menu
            end
          end

          private

          attr_reader :sort_params

          def label_text
            @value.to_s
          end

          def render_sort_link
            a(
              href: sort_params[:url],
              class: themed(:header_cell_link),
              data: {
                action: "click->table-header#headerClick",
                table_header_multi_href: sort_params[:multi_url]
              }
            ) do
              span { plain label_text }
              render_sort_indicator
            end
          end

          def render_sort_indicator
            direction = sort_params[:direction]

            if direction.present?
              span(class: themed(:sort_icon_active)) do
                if direction == "ASC"
                  render Phlex::TablerIcons::ArrowUp.new(class: "w-3 h-3")
                else
                  render Phlex::TablerIcons::ArrowDown.new(class: "w-3 h-3")
                end
              end
              if sort_params[:multi]
                span(class: themed(:sort_priority_badge)) do
                  plain((sort_params[:position] + 1).to_s)
                end
              end
            else
              span(class: themed(:sort_icon_inactive)) do
                render Phlex::TablerIcons::Selector.new(class: "w-3 h-3")
              end
            end
          end

          def render_column_menu
            div(class: "relative group/col-menu", data: {controller: "table-column-menu"}) do
              button(
                type: "button",
                class: themed(:column_menu_trigger),
                data: {action: "click->table-column-menu#toggle"},
                aria: {label: "Column options"}
              ) do
                render Phlex::TablerIcons::Dots.new(class: "w-3 h-3")
              end

              div(
                class: themed(:column_menu_panel),
                data: {"table-column-menu-target": "panel"}
              ) do
                render_menu_item("Clear sort", sort_params[:reset_url], icon: Phlex::TablerIcons::X)
              end
            end
          end

          def render_menu_item(label, href, icon: nil)
            a(href: href, class: themed(:column_menu_item)) do
              render icon.new(class: "w-4 h-4 shrink-0") if icon
              span { plain label }
            end
          end
        end
      end
    end
  end
end
