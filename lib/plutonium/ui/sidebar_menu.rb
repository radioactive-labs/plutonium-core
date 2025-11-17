require "phlexi-menu"

module Plutonium
  module UI
    # A sidebar navigation component that renders a max depth of 2 levels
    # Provides collapsible menu sections and is compatible with turbo-permanent
    class SidebarMenu < Phlexi::Menu::Component
      include Plutonium::UI::Component::Behaviour

      DEFAULT_MAX_DEPTH = 2

      class Theme < Theme
        def self.theme
          super.merge({
            # Base container styles
            nav: "pu-sidebar-menu space-y-sm pb-lg mb-lg",
            items_container: "pu-sidebar-menu-items space-y-sm",

            # Item wrapper styles
            item_wrapper: "pu-sidebar-menu-item w-full transition-colors duration-200 ease-in-out",
            item_parent: nil,

            # Link and button base styles
            item_link: "pu-sidebar-menu-link flex items-center p-sm text-base font-normal text-gray-900 rounded-sm dark:text-white hover:bg-interactive dark:hover:bg-interactive-dark group",
            item_span: "pu-sidebar-menu-button flex items-center p-sm w-full text-base font-normal text-gray-900 rounded-sm transition duration-75 group hover:bg-interactive dark:text-white dark:hover:bg-interactive-dark",

            # Label and content styles
            item_label: ->(depth) { "pu-sidebar-menu-label flex-1 #{(depth > 0) ? "ml-9" : "ml-sm"} text-left whitespace-nowrap" },

            # Badge styles
            leading_badge: "pu-sidebar-menu-badge-leading inline-flex justify-center items-center w-5 h-5 text-xs font-semibold rounded-full text-primary-800 bg-primary-100 dark:bg-primary-200 dark:text-primary-800",
            trailing_badge: "pu-sidebar-menu-badge-trailing inline-flex justify-center items-center px-sm ml-sm text-sm font-medium text-gray-800 bg-elevated rounded-full dark:bg-elevated-dark dark:text-gray-300",

            # Icon styles
            icon_wrapper: "pu-sidebar-menu-icon-wrapper shrink-0 w-6 h-6 flex items-center justify-center",
            icon: "pu-sidebar-menu-icon text-gray-400 transition duration-75 dark:text-gray-400 group-hover:text-gray-900 dark:group-hover:text-white",

            # Collapse icon styles
            collapse_icon: "pu-sidebar-menu-collapse-icon w-6 h-6 ml-auto transition-transform duration-200",
            collapse_icon_expanded: "transform rotate-180",

            # Submenu styles
            sub_items_container: "pu-sidebar-menu-sub-items hidden py-sm space-y-sm",

            # Due to how we use turbo frames, we can't set active states
            active: nil
          })
        end
      end

      protected

      def render_items(items, depth = 0)
        return if depth >= @max_depth || items.empty?

        if depth.zero?
          ul(class: themed(:items_container, depth)) do
            items.each { |item| render_item_wrapper(item, depth) }
          end
        else
          ul(class: themed(:sub_items_container, depth), data: {"resource-collapse-target": "menu"}) do
            items.each { |item| render_item_wrapper(item, depth) }
          end
        end
      end

      # def render_items(items, depth = 0)
      #   return if depth >= @max_depth

      #   if depth.zero?
      #     ul(class: themed(:items_container, depth)) do
      #       items.each do |item|
      #         render_item_wrapper(item, depth)
      #       end
      #     end
      #   else
      #     # Use collapsible rendering for nested levels
      #     ul(
      #       id: generate_menu_id(:root),
      #       class: themed(:sub_items_container, depth),
      #       data: {"resource-collapse-target": "menu"}
      #     ) do
      #       items.each do |item|
      #         render_item_wrapper(item, depth)
      #       end
      #     end
      #   end
      # end

      def render_item_wrapper(item, depth)
        wrapper_attrs = {
          class: tokens(themed(:item_wrapper, depth)),
          data: {}
        }

        if nested?(item, depth)
          wrapper_attrs[:data][:controller] = "resource-collapse"
          wrapper_attrs[:data]["resource-collapse-active-class"] = themed(:collapse_icon_expanded)
        end

        li(**wrapper_attrs) do
          render_item_content(item, depth)
          render_items(item.items, depth + 1) if nested?(item, depth)
        end
      end

      def render_item_content(item, depth)
        if nested?(item, depth)
          render_collapsible_button(item, depth)
        else
          render_item_link(item, depth)
        end
      end

      def render_collapsible_button(item, depth)
        button(
          type: "button",
          class: themed(:item_span, depth),
          data: {
            "resource-collapse-target": "trigger",
            action: "resource-collapse#toggle"
          },
          aria: {
            expanded: "false"
          }
        ) do
          render_item_interior(item, depth)
          render_collapse_icon(depth)
        end
      end

      def render_collapse_icon(depth)
        svg(
          class: themed(:collapse_icon, depth),
          fill: "currentColor",
          viewBox: "0 0 20 20",
          xmlns: "http://www.w3.org/2000/svg",
          aria: {inert: true}
        ) do |s|
          s.path(
            fill_rule: "evenodd",
            d: "M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z",
            clip_rule: "evenodd"
          )
        end
      end
    end
  end
end
