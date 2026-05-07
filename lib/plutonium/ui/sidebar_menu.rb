require "phlexi-menu"

module Plutonium
  module UI
    # A sidebar navigation component that renders a max depth of 2 levels.
    # Provides collapsible menu sections and is compatible with turbo-permanent.
    #
    # Branches on Plutonium.configuration.shell:
    #   :classic → labelled collapsible list
    #   :modern  → icon-only items with flyout for parents and inline children when pinned
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

      # Entry point — branches on shell config before delegating to Phlexi parent
      def view_template
        if Plutonium.configuration.shell == :modern
          render_modern_items(@menu.items, 0)
        else
          super
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

      # -------------------------------------------------------------------------
      # Modern (icon rail) rendering — mirrors IconRail's item logic
      # -------------------------------------------------------------------------

      def render_modern_items(items, depth = 0)
        return if items.nil? || items.empty? || depth >= @max_depth

        items.each { |item| render_modern_item_link(item, depth) }
      end

      def render_modern_item_link(item, depth)
        if item.items.any?
          render_modern_parent_item(item, depth)
        else
          render_modern_leaf_item(item, depth)
        end
      end

      def render_modern_leaf_item(item, depth)
        a(
          href: item.url,
          title: item.label,
          aria: {label: item.label},
          class: "icon-rail-leaf #{modern_leaf_classes(item, depth)}"
        ) do
          render_modern_item_icon(item)
          span(class: "icon-rail-label hidden") { item.label }
        end
      end

      def render_modern_parent_item(item, depth)
        div(
          class: "icon-rail-parent relative w-full flex flex-col items-center",
          data: {controller: "resource-collapse"}
        ) do
          button(
            type: "button",
            title: item.label,
            aria: {label: item.label, expanded: "false"},
            data: {"resource-collapse-target": "trigger", action: "resource-collapse#toggle"},
            class: "icon-rail-parent-trigger #{modern_parent_trigger_classes(item, depth)}"
          ) do
            render_modern_item_icon(item)
            span(class: "icon-rail-label hidden") { item.label }
            span(class: "icon-rail-chevron hidden") do
              render Phlex::TablerIcons::ChevronDown.new(class: "w-4 h-4 ml-auto")
            end
          end

          div(class: "icon-rail-flyout") do
            div(class: "icon-rail-flyout-inner") do
              div(class: "icon-rail-flyout-label") { item.label }
              item.items.each do |child|
                a(href: child.url, class: "icon-rail-flyout-item") { child.label }
              end
            end
          end

          div(
            class: "icon-rail-children hidden w-full",
            data: {"resource-collapse-target": "menu"}
          ) do
            item.items.each do |child|
              a(
                href: child.url,
                title: child.label,
                aria: {label: child.label},
                class: "icon-rail-child #{modern_child_classes(child)}"
              ) do
                span(class: "icon-rail-label") { child.label }
              end
            end
          end
        end
      end

      def render_modern_item_icon(item)
        if item.icon
          render item.icon.new(class: "w-5 h-5 shrink-0")
        else
          span(class: "text-xs font-semibold leading-none shrink-0") { modern_abbreviate(item.label) }
        end
      end

      def modern_leaf_classes(item, depth = 0)
        base = "flex items-center justify-center w-10 h-10 rounded-md transition-colors"
        if modern_active?(item)
          "#{base} bg-primary-100 text-primary-700 dark:bg-primary-900/40 dark:text-primary-300"
        else
          "#{base} text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"
        end
      end

      def modern_parent_trigger_classes(item = nil, depth = 0)
        base = "flex items-center justify-center w-10 h-10 rounded-md transition-colors"
        if item && modern_active?(item)
          "#{base} bg-primary-100 text-primary-700 dark:bg-primary-900/40 dark:text-primary-300"
        else
          "#{base} text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"
        end
      end

      def modern_child_classes(item)
        base = "flex items-center px-3 py-1.5 text-sm rounded-md transition-colors"
        if modern_active?(item)
          "#{base} text-primary-700 dark:text-primary-300 font-medium"
        else
          "#{base} text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"
        end
      end

      def modern_abbreviate(label)
        label.to_s.gsub(/[^a-zA-Z]/, "").first(2).capitalize
      end

      def modern_active?(item)
        item.active?(self)
      end
    end
  end
end
