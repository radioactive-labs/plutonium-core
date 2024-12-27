module Plutonium
  module UI
    class NavUser < Plutonium::UI::Component::Base
      include Phlex::Slotable

      class SectionLink < Plutonium::UI::Component::Base
        include Phlex::Slotable

        slot :leading
        slot :trailing

        def initialize(label:, href:, **attributes)
          @label = label
          @href = href
          @attributes = attributes
        end

        def view_template
          a(
            class: tokens(
              "flex justify-between items-center py-2 px-4 text-sm hover:bg-gray-100 dark:hover:bg-gray-600 dark:hover:text-white",
              @attributes.delete(:class)
            ),
            href: @href,
            **@attributes
          ) do
            span(class: "flex items-center") do
              render leading_slot if leading_slot
              plain @label
            end
            render trailing_slot if trailing_slot?
          end
        end
      end

      class Section < Plutonium::UI::Component::Base
        include Phlex::Slotable

        slot :link, SectionLink, collection: true

        def view_template
          ul(
            class: "text-gray-700 dark:text-gray-300",
            aria: {labelledby: "user-nav-dropdown-toggle"}
          ) do
            link_slots.each do |link|
              li { render link }
            end
          end
        end
      end

      slot :section, Section, collection: true

      def initialize(email:, name: nil, avatar_url: nil)
        @email = email
        @name = name
        @avatar_url = avatar_url
      end

      def view_template
        div(data: {controller: "resource-drop-down"}) do
          render_trigger_button
          render_dropdown_menu
        end
      end

      private

      def render_trigger_button
        if @avatar_url.present?
          render_avatar_button
        else
          render_default_button
        end
      end

      def render_avatar_button
        button(
          type: "button",
          class: "flex mx-3 text-sm bg-gray-800 rounded-full md:mr-0 focus:ring-4 focus:ring-gray-300 dark:focus:ring-gray-600",
          aria: {expanded: "false"},
          id: "user-nav-dropdown-toggle",
          data: {resource_drop_down_target: "trigger"}
        ) do
          span(class: "sr-only") { "Open user menu" }
          img(class: "w-8 h-8 rounded-full", src: @avatar_url, alt: "avatar")
        end
      end

      def render_default_button
        button(
          type: "button",
          class: "flex mx-3 text-sm border border-gray-600 text-gray-500 hover:text-gray-900 hover:bg-gray-100 dark:text-gray-400 dark:hover:text-white dark:hover:bg-gray-700 rounded-full md:mr-0 focus:ring-4 focus:ring-gray-300 dark:focus:ring-gray-600",
          aria: {expanded: "false"},
          id: "user-nav-dropdown-toggle",
          data: {resource_drop_down_target: "trigger"}
        ) do
          span(class: "sr-only") { "Open user menu" }
          render Phlex::TablerIcons::User.new(class: "w-6 h-6")
        end
      end

      def render_dropdown_menu
        div(
          class: "hidden z-50 my-4 w-56 text-base list-none bg-white divide-y divide-gray-100 shadow dark:bg-gray-700 dark:divide-gray-600 rounded-xl",
          data: {resource_drop_down_target: "menu"}
        ) do
          div(class: "py-3 px-4") do
            if @name.present?
              span(class: "block text-sm font-semibold text-gray-900 dark:text-white") { @name }
            end
            span(class: "block text-sm text-gray-900 truncate dark:text-white") { @email }
          end

          section_slots.each { |section| render section }
        end
      end
    end
  end
end
