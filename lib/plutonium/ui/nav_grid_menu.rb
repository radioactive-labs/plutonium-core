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
            class: "block p-4 rounded-[var(--pu-radius-md)] hover:bg-[var(--pu-surface-alt)] group transition-colors",
            href: @href
          ) do
            render @icon.new(
              class: "text-[var(--pu-text-muted)] group-hover:text-[var(--pu-text)] w-8 h-8 mx-auto transition-colors"
            )
            div(class: "text-sm text-[var(--pu-text)] text-center mt-1") { @name }
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
        div(data: {controller: "resource-drop-down"}) do
          render_trigger_button
          render_dropdown_menu
        end
      end

      private

      def render_trigger_button
        button(
          type: "button",
          data: {resource_drop_down_target: "trigger"},
          class: "p-2 text-[var(--pu-text-muted)] rounded-[var(--pu-radius-md)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)] focus:ring-2 focus:ring-[var(--pu-border)] transition-colors"
        ) do
          span(class: "sr-only") { "View #{@label}" }
          render @icon.new(class: "w-6 h-6")
        end
      end

      def render_dropdown_menu
        div(
          class: "hidden overflow-hidden z-50 my-4 max-w-sm text-base list-none bg-[var(--pu-surface)] divide-y divide-[var(--pu-border-muted)] border border-[var(--pu-border)] rounded-[var(--pu-radius-lg)]",
          style: "box-shadow: var(--pu-shadow-lg)",
          data: {resource_drop_down_target: "menu"}
        ) do
          div(
            class: "block py-2 px-4 text-base font-medium text-center text-[var(--pu-text)] bg-[var(--pu-surface-alt)]"
          ) { @label }

          div(class: "grid grid-cols-3 gap-4 p-4") do
            item_slots.each { |item| render item }
          end
        end
      end
    end
  end
end
