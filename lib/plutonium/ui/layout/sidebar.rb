# frozen_string_literal: true

module Plutonium
  module UI
    module Layout
      # A sidebar navigation component that provides a responsive layout with light/dark mode toggle
      # @example Basic usage with navigation content
      #   render Sidebar.new do
      #     ...
      #   end
      class Sidebar < Base
        # Renders the sidebar navigation template
        # @yield [void] The block containing sidebar content
        # @return [void]
        def view_template(&)
          render_sidebar_container do
            render_content(&) if block_given?
          end
        end

        private

        # @private
        def render_sidebar_container(&)
          aside(
            data: {controller: "sidebar"},
            id: "sidebar-navigation",
            aria: {label: "Sidebar Navigation"},
            class: "fixed top-0 left-0 z-40 w-64 h-screen pt-14 transition-transform -translate-x-full lg:translate-x-0",
            &
          )
        end

        # @private
        def render_content(&)
          div(
            id: "sidebar-navigation-content",
            data: {turbo_permanent: true},
            class: "overflow-y-auto py-5 px-3 h-full bg-white border-r border-gray-200 dark:bg-gray-800 dark:border-gray-700",
            &
          )
        end
      end
    end
  end
end
