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
      # @example Basic usage
      #   render IconRail.new(menu: @menu) do |rail|
      #     rail.with_brand { image_tag("logo.svg", class: "w-8 h-8") }
      #   end
      class IconRail < Plutonium::UI::Component::Base
        include Phlex::Slotable

        # @!method brand
        #   Slot for the brand mark rendered at the top of the rail.
        slot :brand

        DEFAULT_MAX_DEPTH = 1

        # @param menu [Phlexi::Menu::Builder, nil] Menu structure (same shape as SidebarMenu)
        # @param max_depth [Integer] Maximum rendering depth (always flat at depth 1)
        def initialize(menu: nil, max_depth: DEFAULT_MAX_DEPTH)
          @menu = menu
          @max_depth = max_depth
        end

        def view_template
          aside(
            id: "sidebar-navigation",
            data: {controller: "sidebar"},
            aria: {label: "Sidebar Navigation"},
            class: "fixed top-0 left-0 z-40 h-screen w-14 " \
                   "bg-[var(--pu-surface)] border-r border-[var(--pu-border)] " \
                   "flex flex-col transition-transform " \
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
            # Reserved for theme toggle, settings, etc. — wired in Task 4.
          end
        end

        # Renders a flat list of nav item links (depth=1, no nesting).
        def render_items(items, depth = 0)
          return if depth >= @max_depth || items.nil? || items.empty?

          items.each { |item| render_item_link(item, depth) }
        end

        def render_item_link(item, depth)
          a(
            href: item.url,
            title: item.label,
            aria: {label: item.label},
            class: link_classes(item)
          ) do
            if item.icon
              render item.icon.new(class: "w-5 h-5")
            else
              span(class: "text-xs font-semibold leading-none") { abbreviate(item.label) }
            end
          end
        end

        def link_classes(item)
          base = "flex items-center justify-center w-10 h-10 rounded-md transition-colors"
          if active?(item)
            "#{base} bg-primary-100 text-primary-700 dark:bg-primary-900/40 dark:text-primary-300"
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
