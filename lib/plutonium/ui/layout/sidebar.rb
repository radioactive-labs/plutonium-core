# frozen_string_literal: true

module Plutonium
  module UI
    module Layout
      # A classic sidebar navigation component that provides a wide, labelled navigation panel.
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
