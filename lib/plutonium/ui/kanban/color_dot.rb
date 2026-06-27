# frozen_string_literal: true

module Plutonium
  module UI
    module Kanban
      # Shared color-dot rendering for the board shell placeholder header
      # (Resource) and the loaded column header (Column), so a column's
      # `color:` shows consistently in both states.
      module ColorDot
        def render_color_dot(color)
          span(
            class: "shrink-0 w-2.5 h-2.5 rounded-full",
            style: "background-color: #{color_css_value(color)}"
          )
        end

        # Maps a column color symbol to a CSS value via Tailwind design tokens.
        # Raw CSS strings (e.g. "#ff0000") are passed through unchanged.
        def color_css_value(color)
          case color.to_sym
          when :red    then "var(--color-red-500)"
          when :orange then "var(--color-orange-500)"
          when :amber  then "var(--color-amber-500)"
          when :yellow then "var(--color-yellow-500)"
          when :green  then "var(--color-green-500)"
          when :blue   then "var(--color-blue-500)"
          when :purple then "var(--color-purple-500)"
          when :pink   then "var(--color-pink-500)"
          when :gray   then "var(--pu-text-muted)"
          else color.to_s
          end
        end
      end
    end
  end
end
