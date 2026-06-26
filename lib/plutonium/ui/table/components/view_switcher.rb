# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        # Segmented control for switching between index views (Table /
        # Grid). Renders nothing unless at least two views are enabled.
        # Selection is persisted in a per-resource cookie that the
        # server reads on the next request — no `?view=` URL pollution
        # so filters / search / clear-x links don't have to thread it
        # through. The Stimulus controller sets the cookie on click,
        # then reloads.
        class ViewSwitcher < Plutonium::UI::Component::Base
          SEGMENT_LABELS = {
            table: {label: "Table", icon: Phlex::TablerIcons::Table},
            grid: {label: "Grid", icon: Phlex::TablerIcons::LayoutGrid},
            kanban: {label: "Board", icon: Phlex::TablerIcons::LayoutKanban}
          }.freeze

          def initialize(views:, current:, cookie_name:, cookie_path: "/")
            @views = views
            @current = current
            @cookie_name = cookie_name
            @cookie_path = cookie_path
          end

          def render?
            @views.size > 1
          end

          def view_template
            div(
              role: "tablist",
              aria: {label: "View"},
              class: "inline-flex h-8 rounded-md border border-[var(--pu-border)] bg-[var(--pu-surface)] overflow-hidden",
              data: {
                controller: "view-switcher",
                view_switcher_cookie_name_value: @cookie_name,
                view_switcher_cookie_path_value: @cookie_path
              }
            ) do
              @views.each_with_index do |key, i|
                render_segment(key, last: i == @views.length - 1)
              end
            end
          end

          private

          def render_segment(key, last:)
            meta = SEGMENT_LABELS.fetch(key) { {label: key.to_s.titleize, icon: Phlex::TablerIcons::LayoutGrid} }
            active = key == @current

            classes = ["px-2.5 inline-flex items-center gap-1.5 text-sm transition-colors"]
            classes << "border-r border-[var(--pu-border)]" unless last
            classes << if active
              "bg-primary-50 text-primary-700 dark:bg-primary-950/40 dark:text-primary-300"
            else
              "text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"
            end

            button(
              type: "button",
              role: "tab",
              class: classes.join(" "),
              title: meta[:label],
              aria: {selected: active.to_s},
              data: {
                action: "click->view-switcher#select",
                view_switcher_view_param: key.to_s
              }
            ) do
              render meta[:icon].new(class: "w-4 h-4 shrink-0")
              span { meta[:label] }
            end
          end
        end
      end
    end
  end
end
