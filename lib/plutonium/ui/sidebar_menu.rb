require "phlexi-menu"

module Plutonium
  module UI
    # This sidebar only renders a max depth of 2
    # It does not set any active states to make it compatible with our use of turbo-permanent
    class SidebarMenu < Phlexi::Menu::Component
      include Plutonium::UI::Component::Behaviour

      class Theme < Theme
        def self.theme
          super.merge({
            # Base container styles
            nav: "space-y-2 pb-6 mb-6",
            items_container: "space-y-2",

            # Item wrapper styles
            item_wrapper: "w-full transition-colors duration-200 ease-in-out",
            item_parent: nil,

            # Link and button base styles
            item_link: "flex items-center p-2 text-base font-normal text-gray-900 rounded-lg dark:text-white hover:bg-gray-100 dark:hover:bg-gray-700 group",
            item_span: "flex items-center p-2 w-full text-base font-normal text-gray-900 rounded-lg transition duration-75 group hover:bg-gray-100 dark:text-white dark:hover:bg-gray-700",

            # Label and content styles
            item_label: "flex-1 ml-3 text-left whitespace-nowrap",

            # Badge styles
            leading_badge: "inline-flex justify-center items-center w-5 h-5 text-xs font-semibold rounded-full text-primary-800 bg-primary-100 dark:bg-primary-200 dark:text-primary-800",
            trailing_badge: "inline-flex justify-center items-center px-2 ml-3 text-sm font-medium text-gray-800 bg-gray-200 rounded-full dark:bg-gray-700 dark:text-gray-300",

            # Icon styles
            icon_wrapper: "shrink-0 w-6 h-6 flex items-center justify-center",
            icon: "text-gray-400 transition duration-75 dark:text-gray-400 group-hover:text-gray-900 dark:group-hover:text-white",

            # Submenu styles
            sub_items_container: "hidden py-2 space-y-2",
            sub_item_link: "flex items-center p-2 pl-11 w-full text-base font-normal text-gray-900 rounded-lg transition duration-75 group hover:bg-gray-100 dark:text-white dark:hover:bg-gray-700",

            # Interactive elements
            collapse_icon: "w-6 h-6 ml-auto transition-transform duration-200",
            collapse_icon_expanded: "transform rotate-180",

            # Due to how we use turbo frames, we can't set active states
            active: nil,
            active_text: nil
          })
        end
      end

      private

      def render_item_wrapper(item, depth)
        wrapper_attrs = build_wrapper_attributes(item)

        li(**wrapper_attrs) do
          render_item_content(item)
          render_sub_items(item, depth + 1) if item.nested?
        end
      end

      def build_wrapper_attributes(item)
        attrs = {
          class: tokens(themed(:item_wrapper), active_class(item)),
          data: {}
        }

        if item.nested?
          attrs[:data][:controller] = "resource-collapse"
          attrs[:data]["resource-collapse-active-class"] = themed(:collapse_icon_expanded)
          attrs[:id] = generate_item_id(item)
        end

        attrs
      end

      def render_item_content(item)
        if item.nested?
          render_collapsible_button(item)
        else
          render_item_link(item)
        end
      end

      def render_collapsible_button(item)
        button(
          type: "button",
          class: themed(:item_span),
          data: {
            "resource-collapse-target": "trigger",
            "action": "resource-collapse#toggle"
          },
          aria: {
            controls: generate_menu_id(item),
            expanded: "false"
          }
        ) do
          render_item_interior(item)
          render_collapse_icon
        end
      end

      def render_collapse_icon
        svg(
          class: themed(:collapse_icon),
          fill: "currentColor",
          viewBox: "0 0 20 20",
          xmlns: "http://www.w3.org/2000/svg",
          aria: { hidden: true }
        ) do |s|
          s.path(
            fill_rule: "evenodd",
            d: "M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z",
            clip_rule: "evenodd"
          )
        end
      end

      def render_sub_items(item, depth)
        return if depth >= @max_depth

        ul(
          id: generate_menu_id(item),
          class: themed(:sub_items_container),
          data: { "resource-collapse-target": "menu" }
        ) do
          item.items.each do |sub_item|
            render_sub_item(sub_item)
          end
        end
      end

      def render_sub_item(sub_item)
        li do
          a(
            href: sub_item.url,
            class: tokens(
              themed(:sub_item_link),
              active_class(sub_item),
              sub_item.nested? ? themed(:item_parent) : nil
            )
          ) do
            render_label(sub_item.label)
            render_trailing_badge(sub_item.trailing_badge) if sub_item.trailing_badge
          end
        end
      end

      def render_icon(icon)
        return unless icon

        if icon.is_a?(String)
          div(class: themed(:icon_wrapper)) { unsafe_raw("&nbsp;") }
        else
          div(class: themed(:icon_wrapper)) do
            render icon.new(class: themed(:icon))
          end
        end
      end

      def generate_item_id(item)
        "sidebar-menu-item-#{item.label.to_s.parameterize}"
      end

      def generate_menu_id(item)
        "#{generate_item_id(item)}-menu"
      end

      def active_class(item)
        if item.active?(self)
          tokens(themed(:active), themed(:active_text))
        end
      end
    end
  end
end
