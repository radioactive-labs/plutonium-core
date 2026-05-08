# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        class ViewSwitcher < Plutonium::UI::Component::Base
          SEGMENTS = [
            {key: :grid, label: "Grid", icon: Phlex::TablerIcons::LayoutGrid, enabled: true},
            {key: :cards, label: "Cards", icon: Phlex::TablerIcons::LayoutCards, enabled: false},
            {key: :kanban, label: "Kanban", icon: Phlex::TablerIcons::LayoutKanban, enabled: false}
          ].freeze

          def initialize(active: :grid)
            @active = active
          end

          def view_template
            div(
              role: "tablist",
              aria: {label: "View"},
              class: "inline-flex h-8 rounded-md border border-[var(--pu-border)] bg-[var(--pu-surface)] overflow-hidden"
            ) do
              SEGMENTS.each_with_index do |segment, i|
                render_segment(segment, last: i == SEGMENTS.length - 1)
              end
            end
          end

          private

          def render_segment(segment, last:)
            classes = ["px-2.5 inline-flex items-center gap-1.5 text-sm transition-colors"]
            classes << "border-r border-[var(--pu-border)]" unless last
            classes << if segment[:enabled] && segment[:key] == @active
              "bg-primary-50 text-primary-700 dark:bg-primary-950/40 dark:text-primary-300"
            elsif segment[:enabled]
              "text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"
            else
              "text-[var(--pu-text-muted)] opacity-60 cursor-not-allowed"
            end

            button_args = {
              type: "button",
              role: "tab",
              class: classes.join(" "),
              title: segment[:enabled] ? segment[:label] : "#{segment[:label]} — Coming soon",
              aria: {selected: segment[:enabled] && segment[:key] == @active}
            }
            button_args[:disabled] = true unless segment[:enabled]

            button(**button_args) do
              render segment[:icon].new(class: "w-4 h-4 shrink-0")
              span { segment[:label] }
            end
          end
        end
      end
    end
  end
end
