module Plutonium
  module UI
    # A responsive grid-based navigation menu component that displays a collection of Item
    # components in a dropdown format. The menu includes a trigger button with an icon and a dropdown
    # panel containing a grid of navigation items.
    #
    # @example Basic usage
    #   render Plutonium::UI:NavGridMenu.new(label: "Resources", icon: Phlex::TablerIcons::Grid) do |menu|
    #     menu.with_item(name: "Dashboard", icon: Phlex::TablerIcons::Dashboard, href: "/dashboard")
    #     menu.with_item(name: "Settings", icon: Phlex::TablerIcons::Settings, href: "/settings")
    #   end
    #
    class NavGridMenu < Plutonium::UI::Component::Base
      include Phlex::Slotable

      # A grid-based navigation menu item component that represents a single clickable item
      # within a NavGridMenu. Each item consists of an icon and label that links to a specific URL.
      #
      # @example Basic usage
      #   render Plutonium::UI::NavGridMenu::Item.new(
      #     name: "Dashboard",
      #     icon: "chart",
      #     href: "/dashboard"
      #   )
      #
      class Item < Plutonium::UI::Component::Base
        def initialize(name:, icon:, href:)
          @name = name
          @icon = icon
          @href = href
        end

        def view_template
          a(
            class: tokens(theme_class(:nav, variant: :grid, element: :item), "block p-md rounded-sm hover:bg-interactive dark:hover:bg-interactive-dark group"),
            href: @href
          ) do
            render @icon.new(
              class: "text-gray-400 group-hover:text-gray-500 dark:text-gray-200 dark:group-hover:text-gray-400 w-8 h-8 mx-auto"
            )
            div(class: "text-sm text-gray-900 dark:text-white text-center") { @name }
          end
        end
      end

      # Defines the menu items slot collection
      # @!method item
      #   Renders a Item component
      #   @yield The block containing the menu item content
      slot :item, Item, collection: true

      def initialize(label:, icon:)
        @label = label
        @icon = icon
      end

      def view_template
        div(class: theme_class(:nav, variant: :grid), data: {controller: "resource-drop-down"}) do
          render_trigger_button
          render_dropdown_menu
        end
      end

      private

      def render_trigger_button
        button(
          type: "button",
          data: {resource_drop_down_target: "trigger"},
          class: tokens(theme_class(:nav, variant: :grid, element: :trigger), "p-2 text-gray-500 rounded-sm hover:text-gray-900 hover:bg-interactive dark:text-gray-200 dark:hover:text-white dark:hover:bg-interactive-dark focus:ring-4 focus:ring-gray-300 dark:focus:ring-gray-600")
        ) do
          span(class: "sr-only") { "View #{@label}" }
          render @icon.new(class: "w-6 h-6")
        end
      end

      def render_dropdown_menu
        div(
          class: tokens(theme_class(:nav, variant: :grid, element: :dropdown), "hidden overflow-hidden z-50 my-md max-w-sm text-base list-none bg-surface divide-y divide-gray-100 shadow-lg dark:bg-elevated-dark dark:divide-gray-600 rounded"),
          data: {resource_drop_down_target: "menu"}
        ) do
          div(
            class: "block py-sm px-md text-base font-medium text-center text-gray-700 bg-page dark:bg-gray-600 dark:text-gray-300"
          ) { @label }

          div(class: "grid grid-cols-3 gap-md p-md") do
            item_slots.each { |item| render item }
          end
        end
      end
    end
  end
end
