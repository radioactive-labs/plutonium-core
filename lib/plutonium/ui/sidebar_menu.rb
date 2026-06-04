require "phlexi-menu"

module Plutonium
  module UI
    # A sidebar navigation component that renders a max depth of 2 levels.
    # Provides collapsible menu sections and is compatible with turbo-permanent.
    class SidebarMenu < Phlexi::Menu::Component
      include Plutonium::UI::Component::Behaviour

      DEFAULT_MAX_DEPTH = 2

      class Theme < Theme
        def self.theme
          super.merge({
            # Base container styles
            nav: "space-y-2 pb-6 mb-6",
            items_container: "space-y-1",

            # Item wrapper styles
            item_wrapper: "w-full transition-colors duration-200 ease-in-out",
            item_parent: nil,

            # Link and button base styles
            item_link: "flex items-center p-2.5 text-base font-medium text-[var(--pu-text)] rounded-[var(--pu-radius-md)] hover:bg-[var(--pu-surface-alt)] group transition-colors",
            item_span: "flex items-center p-2.5 w-full text-base font-medium text-[var(--pu-text)] rounded-[var(--pu-radius-md)] transition-colors group hover:bg-[var(--pu-surface-alt)]",

            # Label and content styles
            item_label: ->(depth) { "flex-1 #{(depth > 0) ? "ml-9" : "ml-3"} text-left whitespace-nowrap" },

            # Badge styles
            leading_badge: "inline-flex justify-center items-center w-5 h-5 text-xs font-semibold rounded-full text-primary-700 bg-primary-100 dark:bg-primary-900/50 dark:text-primary-300",
            trailing_badge: "inline-flex justify-center items-center px-2 ml-3 text-sm font-medium text-[var(--pu-text-muted)] bg-[var(--pu-surface-alt)] rounded-full",

            # Icon styles
            icon_wrapper: "shrink-0 w-6 h-6 flex items-center justify-center",
            icon: "text-[var(--pu-text-muted)] transition-colors group-hover:text-[var(--pu-text)]",

            # Collapse icon styles
            collapse_icon: "w-6 h-6 ml-auto transition-transform duration-200 text-[var(--pu-text-muted)]",
            collapse_icon_expanded: "transform rotate-180",

            # Submenu styles
            sub_items_container: "hidden py-2 space-y-1",

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

      # Spread any per-item HTML attributes (target:, rel:, data:, …) the item
      # opts into via its Phlexi::Menu options — e.g. a menu item that opens a
      # full-screen SPA in its own tab. The base Phlexi implementation
      # hardcodes the anchor and drops these, so we re-render the leaf.
      def render_item_link(item, depth)
        link_class = themed(:item_link, depth)
        active = active_class(item, depth)
        classes = active ? "#{link_class} #{active}" : link_class

        a(href: item.url, **item_link_attributes(item, classes)) do
          render_item_interior(item, depth)
        end
      end

      # Anchor attributes opted into via Phlexi::Menu item options (target:,
      # rel:, data:, aria:, …), minus Phlexi's own :active key (which must not
      # leak onto the <a>). A user-supplied :class merges with the themed base
      # classes; base_data / base_aria (none on the plain leaf today) always
      # win so options extend rather than replace framework wiring.
      def item_link_attributes(item, base_class, base_data: {}, base_aria: {})
        opts = (item.options || {}).except(:active)
        data = (opts[:data] || {}).merge(base_data)
        aria = (opts[:aria] || {}).merge(base_aria)
        opts[:class] = [base_class, opts[:class]].compact.join(" ")
        opts[:data] = data unless data.empty?
        opts[:aria] = aria unless aria.empty?
        opts
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
