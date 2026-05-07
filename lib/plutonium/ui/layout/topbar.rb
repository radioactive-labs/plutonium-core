# frozen_string_literal: true

require "phlex/slotable"

module Plutonium
  module UI
    module Layout
      # A sticky 48px topbar with breadcrumbs (left), search (center), and actions (right).
      # Pairs with IconRail — offset by `lg:left-14` on desktop to clear the rail.
      #
      # @example With all slots
      #   render Topbar.new do |bar|
      #     bar.with_breadcrumbs { render BreadcrumbComponent.new }
      #     bar.with_search     { render SearchComponent.new }
      #     bar.with_action     { render UserMenuComponent.new }
      #   end
      class Topbar < Plutonium::UI::Component::Base
        include Phlex::Slotable
        include Phlex::Rails::Helpers::Routes

        # @!method breadcrumbs
        #   Slot for breadcrumb navigation rendered on the left.
        slot :breadcrumbs

        # @!method search
        #   Slot for a search widget rendered in the center (max-w-[360px]).
        slot :search

        # @!method action
        #   Collection slot for icon buttons / dropdowns rendered on the right.
        slot :action, collection: true

        def view_template
          nav(
            class: "fixed top-0 right-0 left-0 lg:left-14 z-30 h-12 " \
                   "bg-[var(--pu-surface)] border-b border-[var(--pu-border)] " \
                   "flex items-center gap-3 px-4",
            data: {
              controller: "resource-header",
              resource_header_sidebar_outlet: "#sidebar-navigation"
            }
          ) do
            render_hamburger
            render_breadcrumbs_section
            render_search_section
            render_actions_section
          end
        end

        private

        def render_hamburger
          button(
            type: "button",
            data_action: "resource-header#toggleDrawer",
            aria_controls: "#sidebar-navigation",
            aria_label: "Toggle sidebar",
            class: "p-1.5 -ml-1.5 text-[var(--pu-text-muted)] rounded-md " \
                   "hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)] " \
                   "lg:hidden transition-colors"
          ) do
            render_hamburger_icons
          end
        end

        def render_hamburger_icons
          span(data_resource_header_target: "openIcon") do
            render Phlex::TablerIcons::Menu.new(class: "w-5 h-5")
          end
          span(data_resource_header_target: "closeIcon", class: "hidden", aria_hidden: "true") do
            render Phlex::TablerIcons::X.new(class: "w-5 h-5")
          end
          span(class: "sr-only") { "Toggle sidebar" }
        end

        def render_breadcrumbs_section
          return unless breadcrumbs_slot?
          div(class: "flex items-center min-w-0 flex-shrink") do
            render breadcrumbs_slot
          end
        end

        def render_search_section
          return unless search_slot?
          div(class: "flex-1 flex justify-center") do
            div(class: "w-full max-w-[360px]") { render search_slot }
          end
        end

        def render_actions_section
          return unless action_slots?
          div(class: "ml-auto flex items-center gap-1.5") do
            action_slots.each { |action| render action }
          end
        end
      end
    end
  end
end
