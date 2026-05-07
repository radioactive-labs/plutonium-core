# frozen_string_literal: true

module Plutonium
  module UI
    module Layout
      # A sidebar navigation component that provides a responsive layout with light/dark mode toggle.
      # Branches on Plutonium.configuration.shell:
      #   :classic → wide 64-column sidebar (w-64) with full labels
      #   :modern  → narrow 56px icon rail (w-14) with flyout/pinned interactions
      #
      # @example Basic usage with navigation content
      #   render Sidebar.new do
      #     render SidebarMenu.new(menu)
      #   end
      class Sidebar < Base
        # Renders the sidebar navigation template
        # @yield [void] The block containing sidebar content
        # @return [void]
        def view_template(&)
          if Plutonium.configuration.shell == :modern
            render_modern(&)
          else
            render_classic(&)
          end
        end

        private

        # Renders the narrow icon rail shell for the modern shell config
        # @private
        def render_modern(&)
          aside(
            id: "sidebar-navigation",
            data: {controller: "sidebar icon-rail"},
            aria: {label: "Sidebar Navigation"},
            class: "fixed top-0 left-0 z-40 h-screen " \
                   "bg-[var(--pu-surface)] border-r border-[var(--pu-border)] " \
                   "flex flex-col transition-[width] duration-200 overflow-x-hidden " \
                   "-translate-x-full lg:translate-x-0"
          ) do
            div(
              id: "sidebar-navigation-content",
              data: {turbo_permanent: true, sidebar_target: "scroll"},
              class: "flex-1 overflow-y-auto py-3 flex flex-col items-center gap-1",
              &
            )
            render_modern_footer
          end
        end

        # Renders the pin button in the footer of the modern rail
        # @private
        def render_modern_footer
          div(class: "py-3 flex flex-col items-center gap-1 border-t border-[var(--pu-border)] shrink-0") do
            button(
              type: "button",
              title: "Toggle sidebar",
              aria: {label: "Toggle sidebar pin"},
              data: {action: "icon-rail#togglePin"},
              class: "flex items-center justify-center w-10 h-10 rounded-md transition-colors " \
                     "text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"
            ) do
              span(class: "icon-rail-pin-collapse hidden") do
                render Phlex::TablerIcons::LayoutSidebarLeftCollapse.new(class: "w-5 h-5")
              end
              span(class: "icon-rail-pin-expand") do
                render Phlex::TablerIcons::LayoutSidebarLeftExpand.new(class: "w-5 h-5")
              end
            end
          end
        end

        # Renders the classic wide sidebar
        # @private
        def render_classic(&)
          aside(
            data: {controller: "sidebar"},
            id: "sidebar-navigation",
            aria: {label: "Sidebar Navigation"},
            class: "fixed top-0 left-0 z-40 w-64 h-screen pt-14 transition-transform -translate-x-full lg:translate-x-0"
          ) do
            div(
              id: "sidebar-navigation-content",
              data: {turbo_permanent: true, sidebar_target: "scroll"},
              class: "overflow-y-auto py-5 px-3 h-full bg-[var(--pu-surface)] border-r border-[var(--pu-border)]",
              &
            )
          end
        end
      end
    end
  end
end
