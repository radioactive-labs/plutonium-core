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
            class: "fixed top-0 left-0 z-40 h-screen w-14 " \
                   "bg-[var(--pu-surface)] border-r border-[var(--pu-border)] " \
                   "flex flex-col transition-all duration-300 " \
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
            data: {turbo_permanent: true, sidebar_target: "scroll"},
            class: "flex-1 overflow-y-auto py-3 flex flex-col items-center gap-1"
          ) do
            render_items(@menu.items, 0) if @menu&.items
          end
        end

        def render_footer_section
          div(class: "py-3 flex flex-col items-center gap-1 border-t border-[var(--pu-border)] shrink-0") do
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
            aria: {label: item.label},
            class: "icon-rail-leaf #{leaf_classes(item, depth)}"
          ) do
            render_item_icon(item)
            span(class: "icon-rail-label hidden") { item.label }
          end
        end

        def render_parent_item(item, depth)
          div(
            class: "icon-rail-parent relative w-full flex flex-col items-center",
            data: {controller: "resource-collapse"}
          ) do
            # Trigger button — acts as parent toggle in pinned mode; flyout trigger in collapsed
            button(
              type: "button",
              title: item.label,
              aria: {label: item.label, expanded: "false"},
              data: {"resource-collapse-target": "trigger", action: "resource-collapse#toggle"},
              class: "icon-rail-parent-trigger #{parent_trigger_classes(item, depth)}"
            ) do
              render_item_icon(item)
              span(class: "icon-rail-label hidden") { item.label }
              span(class: "icon-rail-chevron hidden") do
                render Phlex::TablerIcons::ChevronDown.new(class: "w-4 h-4 ml-auto")
              end
            end

            # Flyout panel — visible on hover in collapsed mode (CSS-only)
            div(class: "icon-rail-flyout") do
              div(class: "icon-rail-flyout-inner") do
                div(class: "icon-rail-flyout-label") { item.label }
                item.items.each do |child|
                  a(href: child.url, class: "icon-rail-flyout-item") { child.label }
                end
              end
            end

            # Inline children — shown in pinned mode by resource-collapse controller
            div(
              class: "icon-rail-children hidden w-full",
              data: {"resource-collapse-target": "menu"}
            ) do
              item.items.each do |child|
                a(
                  href: child.url,
                  title: child.label,
                  aria: {label: child.label},
                  class: "icon-rail-child #{child_classes(child)}"
                ) do
                  span(class: "icon-rail-label") { child.label }
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
          base = "flex items-center justify-center w-10 h-10 rounded-md transition-colors"
          if item && active?(item)
            "#{base} bg-primary-100 text-primary-700 dark:bg-primary-900/40 dark:text-primary-300"
          else
            "#{base} text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"
          end
        end

        def child_classes(item)
          base = "flex items-center px-3 py-1.5 text-sm rounded-md transition-colors"
          if active?(item)
            "#{base} text-primary-700 dark:text-primary-300 font-medium"
          else
            "#{base} text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)]"
          end
        end

        # Returns the first 2 letters of the label (letters only, capitalised).
        def abbreviate(label)
          label.to_s.gsub(/[^a-zA-Z]/, "").first(2).capitalize
        end

        def active?(item)
          item.active?(self)
        end
      end
    end
  end
end
