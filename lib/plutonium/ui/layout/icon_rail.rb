# frozen_string_literal: true

require "phlexi-menu"
require "phlex/slotable"

module Plutonium
  module UI
    module Layout
      # A fixed 56px-wide icon-only navigation rail for the app shell.
      # Renders nav items as icon buttons with tooltips; falls back to a 2-letter
      # abbreviation when an item has no icon.
      #
      # When items have children:
      # - Collapsed (default): hovering the parent shows a CSS flyout to the right
      # - Pinned (body.pu-rail-pinned): rail expands to 220px, children collapse inline
      #
      # @example Basic usage
      #   render IconRail.new(menu: @menu) do |rail|
      #     rail.with_brand { image_tag("logo.svg", class: "w-8 h-8") }
      #   end
      class IconRail < Plutonium::UI::Component::Base
        include Phlex::Slotable

        # @!method brand
        #   Slot for the brand mark rendered at the top of the rail.
        slot :brand

        DEFAULT_MAX_DEPTH = 2

        # @param menu [Phlexi::Menu::Builder, nil] Menu structure (same shape as SidebarMenu)
        # @param max_depth [Integer] Maximum rendering depth (depth 2 supports parent+children)
        def initialize(menu: nil, max_depth: DEFAULT_MAX_DEPTH)
          @menu = menu
          @max_depth = max_depth
        end

        def view_template
          aside(
            id: "sidebar-navigation",
            data: {controller: "sidebar icon-rail"},
            aria: {label: "Sidebar Navigation"},
            class: "fixed top-0 left-0 z-40 h-dvh " \
                   "bg-[var(--pu-surface)] border-r border-[var(--pu-border)] " \
                   "flex flex-col transition-[width] duration-200 overflow-x-hidden " \
                   "-translate-x-full lg:translate-x-0"
          ) do
            render_brand_section
            render_nav_section
            render_footer_section
          end
        end

        private

        def render_brand_section
          div(class: "h-12 flex items-center justify-center border-b border-[var(--pu-border)] shrink-0") do
            render brand_slot if brand_slot?
          end
        end

        def render_nav_section
          div(
            id: "sidebar-navigation-content",
            data: {sidebar_target: "scroll"},
            class: "flex-1 overflow-y-auto py-3 flex flex-col items-center gap-1"
          ) do
            render_items(@menu.items, 0) if @menu&.items
          end
        end

        def render_footer_section
          div(class: "h-14 flex items-center justify-center border-t border-[var(--pu-border)] shrink-0") do
            render_pin_button
          end
        end

        def render_pin_button
          button(
            type: "button",
            title: "Toggle sidebar",
            aria: {label: "Toggle sidebar pin"},
            data: {action: "icon-rail#togglePin"},
            class: "flex items-center justify-center w-10 h-10 rounded-md transition-colors " \
                   "text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"
          ) do
            # Collapse icon: shown when pinned (body.pu-rail-pinned)
            span(class: "icon-rail-pin-collapse hidden") do
              render Phlex::TablerIcons::LayoutSidebarLeftCollapse.new(class: "w-5 h-5")
            end
            # Expand icon: shown when collapsed (default)
            span(class: "icon-rail-pin-expand") do
              render Phlex::TablerIcons::LayoutSidebarLeftExpand.new(class: "w-5 h-5")
            end
          end
        end

        # Renders nav items up to @max_depth.
        def render_items(items, depth = 0)
          return if depth >= @max_depth || items.nil? || items.empty?

          items.each { |item| render_item_link(item, depth) }
        end

        def render_item_link(item, depth)
          if item.items.any?
            render_parent_item(item, depth)
          else
            render_leaf_item(item, depth)
          end
        end

        def render_leaf_item(item, depth)
          a(
            href: item.url,
            title: item.label,
            **item_link_attributes(item, "icon-rail-leaf #{leaf_classes(item, depth)}", base_aria: {label: item.label})
          ) do
            render_item_icon(item)
            span(class: "icon-rail-label hidden") { item.label }
          end
        end

        def render_parent_item(item, depth)
          div(
            class: "icon-rail-parent relative w-full flex flex-col items-center",
            data: {
              controller: "icon-rail-flyout",
              action:
                "mouseenter->icon-rail-flyout#open " \
                "mouseleave->icon-rail-flyout#scheduleClose " \
                "focusin->icon-rail-flyout#open " \
                "focusout->icon-rail-flyout#scheduleClose " \
                "keydown.esc@window->icon-rail-flyout#closeOnEsc"
            }
          ) do
            a(
              href: item.url || "#",
              title: item.label,
              **item_link_attributes(
                item,
                "icon-rail-parent-trigger #{parent_trigger_classes(item, depth)}",
                base_aria: {label: item.label, haspopup: "menu", expanded: "false"},
                base_data: {"icon-rail-flyout-target": "trigger", action: "click->icon-rail-flyout#toggle"}
              )
            ) do
              render_item_icon(item)
              span(class: "icon-rail-label") { item.label }
              span(class: "icon-rail-chevron", aria_hidden: "true") do
                render Phlex::TablerIcons::ChevronRight.new(class: "w-full h-full")
              end
            end

            div(
              class: "icon-rail-flyout",
              role: "menu",
              data: {"icon-rail-flyout-target": "panel"}
            ) do
              div(class: "icon-rail-flyout-inner") do
                div(class: "icon-rail-flyout-label") { item.label }
                item.items.each do |child|
                  a(
                    href: child.url,
                    role: "menuitem",
                    **item_link_attributes(child, "icon-rail-flyout-item")
                  ) { child.label }
                end
              end
            end
          end
        end

        def render_item_icon(item)
          if item.icon
            render item.icon.new(class: "w-5 h-5 shrink-0")
          else
            span(class: "text-xs font-semibold leading-none shrink-0") { abbreviate(item.label) }
          end
        end

        def leaf_classes(item, depth = 0)
          base = "flex items-center justify-center w-10 h-10 rounded-md transition-colors"
          if active?(item)
            "#{base} bg-primary-100 text-primary-700 dark:bg-primary-900/40 dark:text-primary-300"
          else
            "#{base} text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"
          end
        end

        def parent_trigger_classes(item = nil, depth = 0)
          base = "relative flex items-center justify-center w-10 h-10 rounded-md transition-colors"
          if item && parent_active?(item)
            "#{base} bg-primary-100 text-primary-700 dark:bg-primary-900/40 dark:text-primary-300"
          else
            "#{base} text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"
          end
        end

        # A parent item is "active" if itself or any descendant is active —
        # so the highlight follows the user into nested children.
        def parent_active?(item)
          active?(item) || item.items.any? { |child| active?(child) }
        end

        # Returns the first 2 letters of the label (letters only, capitalised).
        def abbreviate(label)
          label.to_s.gsub(/[^a-zA-Z]/, "").first(2).capitalize
        end

        def active?(item)
          item.active?(self)
        end

        # Anchor attributes a menu item opts into via its Phlexi::Menu options
        # (target:, rel:, data:, aria:, …), merged with the anchor's own
        # framework attributes and spread onto the <a>. The framework's
        # class / data / aria (base styling, flyout wiring, popup semantics)
        # take precedence so a menu item can *extend* the link without breaking
        # navigation behavior. Phlexi keeps its own :active key in options,
        # which must never become an attribute.
        def item_link_attributes(item, base_class, base_data: {}, base_aria: {})
          opts = (item.options || {}).except(:active)
          data = (opts[:data] || {}).merge(base_data)
          aria = (opts[:aria] || {}).merge(base_aria)
          opts[:class] = [base_class, opts[:class]].compact.join(" ")
          opts[:data] = data unless data.empty?
          opts[:aria] = aria unless aria.empty?
          opts
        end
      end
    end
  end
end
