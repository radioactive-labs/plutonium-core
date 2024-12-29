require "phlex/slotable"

module Plutonium
  module UI
    module Layout
      # @class Header
      # A flexible, responsive header component that can include brand information, navigation elements,
      # and custom actions.
      #
      # @example Basic usage with brand name
      #   Header.new do |header|
      #     header.with_brand_name { "My App" }
      #   end
      #
      # @example With brand logo and actions
      #   Header.new do |header|
      #     header.with_brand_logo { image_tag("logo.svg") }
      #     header.with_action { button "Settings" }
      #   end
      class Header < Base
        include Phlex::Slotable
        include Phlex::Rails::Helpers::Routes

        # @!method brand_name
        #   Defines the slot for the brand name content
        #   @yield The block containing the brand name content
        slot :brand_name

        # @!method brand_logo
        #   Defines the slot for the brand logo content
        #   @yield The block containing the brand logo content
        slot :brand_logo

        # @!method action
        #   Defines multiple slots for header actions (e.g., buttons, dropdowns)
        #   @yield The block containing each action's content
        slot :action, collection: true

        # Renders the header component with all its configured elements
        # @note The header is fixed positioned and includes responsive design considerations
        # @return [void]
        def view_template
          nav(
            class: "bg-white border-b border-gray-200 px-4 py-2.5 dark:bg-gray-800 dark:border-gray-700 fixed left-0 right-0 top-0 z-50",
            data: {
              controller: "resource-header",
              header_sidebar_outlet: "#sidebar-navigation"
            }
          ) do
            div(class: "flex flex-wrap justify-between items-center") do
              render_brand_section
              render_actions if action_slots?
            end
          end
        end

        private

        # Renders the left section of the header including sidebar toggle, brand elements,
        # and any yielded content
        # @private
        def render_brand_section
          div(class: "flex justify-start items-center") do
            render_sidebar_toggle
            render_brand if brand_name_slot? || brand_logo_slot?
          end
        end

        # Renders the sidebar toggle button for mobile views
        # @private
        def render_sidebar_toggle
          button(
            data_action: "header#toggleDrawer",
            aria_controls: "#sidebar-navigation",
            class: %(p-2 mr-2 text-gray-600 rounded-lg cursor-pointer lg:hidden hover:text-gray-900
                    hover:bg-gray-100 focus:bg-gray-100 dark:focus:bg-gray-700 focus:ring-2
                    focus:ring-gray-100 dark:focus:ring-gray-700 dark:text-gray-200
                    dark:hover:bg-gray-700 dark:hover:text-white)
          ) do
            render_toggle_icons
          end
        end

        # Renders the brand section with logo and/or name
        # @private
        def render_brand
          a(href: root_path, class: "flex items-center space-x-2 md:min-w-60") do
            render brand_logo_slot if brand_logo_slot?
            if brand_name_slot?
              span(class: "self-center text-2xl font-semibold whitespace-nowrap dark:text-white hidden xs:block") do
                render brand_name_slot
              end
            end
          end
        end

        # Renders the toggle icons for the sidebar button
        # @private
        def render_toggle_icons
          span(data_header_target: "openIcon") do
            render Phlex::TablerIcons::Menu.new(class: "w-6 h-6")
          end

          span(data_header_target: "closeIcon", class: "hidden", aria_hidden: "true") do
            render Phlex::TablerIcons::X.new(class: "w-6 h-6")
          end

          span(class: "sr-only") { "Toggle sidebar" }
        end

        # Renders the action buttons section
        # @private
        def render_actions
          div(class: "flex items-center lg:order-2") do
            action_slots.each { |action| render action }
          end
        end
      end
    end
  end
end
