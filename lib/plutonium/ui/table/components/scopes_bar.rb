# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        class ScopesBar < Plutonium::UI::Component::Base
          include Plutonium::UI::Component::Behaviour

          def view_template
            div(
              class:
                # "flex flex-wrap justify-between items-center gap-4 p-4 bg-white border border-gray-200 rounded-lg dark:bg-gray-800 dark:border-gray-700 mb-4"
                "flex flex-wrap justify-between items-center gap-4 mb-4"
            ) do
              div(class: "flex flex-wrap items-center gap-2") do
                name = "all"
                if current_scope.blank?
                  a(
                    id: "#{name}-scope",
                    href: current_query_object.build_url(scope: nil),
                    class:
                      "px-4 py-2 text-sm font-medium text-white bg-primary-700 border border-primary-700 rounded-lg hover:bg-primary-800 focus:z-10 focus:ring-2 focus:ring-primary-700 focus:text-white dark:bg-primary-600 dark:border-primary-600 dark:hover:bg-primary-700 dark:focus:ring-primary-800"
                  ) { name.humanize }
                else
                  a(
                    id: "#{name}-scope",
                    href: current_query_object.build_url(scope: nil),
                    class:
                      "px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-lg hover:bg-gray-100 hover:text-gray-700 focus:z-10 focus:ring-2 focus:ring-gray-300 focus:text-gray-700 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-600 dark:hover:text-white dark:hover:bg-gray-700 dark:focus:ring-gray-700 dark:focus:text-white"
                  ) { name.humanize }
                end

                current_query_object.scope_definitions.each do |name, definition|
                  if name == current_scope
                    a(
                      id: "#{name}-scope",
                      href: current_query_object.build_url(scope: name),
                      class:
                        "px-4 py-2 text-sm font-medium text-white bg-primary-700 border border-primary-700 rounded-lg hover:bg-primary-800 focus:z-10 focus:ring-2 focus:ring-primary-700 focus:text-white dark:bg-primary-600 dark:border-primary-600 dark:hover:bg-primary-700 dark:focus:ring-primary-800"
                    ) { name.humanize }
                  else
                    a(
                      id: "#{name}-scope",
                      href: current_query_object.build_url(scope: name),
                      class:
                        "px-4 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-lg hover:bg-gray-100 hover:text-gray-700 focus:z-10 focus:ring-2 focus:ring-gray-300 focus:text-gray-700 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-600 dark:hover:text-white dark:hover:bg-gray-700 dark:focus:ring-gray-700 dark:focus:text-white"
                    ) { name.humanize }
                  end
                end
              end

              # div(class: "flex flex-wrap items-center gap-2") do
              #   button(
              #     class:
              #       "inline-flex items-center px-3 py-2 text-sm font-medium text-white bg-red-700 rounded-lg hover:bg-red-800 focus:ring-4 focus:outline-none focus:ring-red-300 dark:bg-red-600 dark:hover:bg-red-700 dark:focus:ring-red-800"
              #   ) do
              #     svg(
              #       class: "w-4 h-4 mr-2",
              #       fill: "none",
              #       stroke: "currentColor",
              #       viewbox: "0 0 24 24",
              #       xmlns: "http://www.w3.org/2000/svg"
              #     ) do |s|
              #       s.path(
              #         stroke_linecap: "round",
              #         stroke_linejoin: "round",
              #         stroke_width: "2",
              #         d:
              #           "M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
              #       )
              #     end
              #     plain " Delete Selected "
              #   end
              #   button(
              #     class:
              #       "inline-flex items-center px-3 py-2 text-sm font-medium text-white bg-yellow-700 rounded-lg hover:bg-yellow-800 focus:ring-4 focus:outline-none focus:ring-yellow-300 dark:bg-yellow-600 dark:hover:bg-yellow-700 dark:focus:ring-yellow-800"
              #   ) do
              #     svg(
              #       class: "w-4 h-4 mr-2",
              #       fill: "none",
              #       stroke: "currentColor",
              #       viewbox: "0 0 24 24",
              #       xmlns: "http://www.w3.org/2000/svg"
              #     ) do |s|
              #       s.path(
              #         stroke_linecap: "round",
              #         stroke_linejoin: "round",
              #         stroke_width: "2",
              #         d:
              #           "M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4"
              #       )
              #     end
              #     plain " Archive Selected "
              #   end
              #   button(
              #     id: "dropdownActionButton",
              #     data_dropdown_toggle: "dropdownAction",
              #     class:
              #       "inline-flex items-center text-gray-500 bg-white border border-gray-300 focus:outline-none hover:bg-gray-100 focus:ring-4 focus:ring-gray-200 font-medium rounded-lg text-sm px-3 py-2 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-600 dark:hover:bg-gray-700 dark:hover:border-gray-600 dark:focus:ring-gray-700",
              #     type: "button"
              #   ) do
              #     span(class: "sr-only") { "Action button" }
              #     plain " More Actions "
              #     svg(
              #       class: "w-2.5 h-2.5 ml-2.5",
              #       aria_hidden: "true",
              #       xmlns: "http://www.w3.org/2000/svg",
              #       fill: "none",
              #       viewbox: "0 0 10 6"
              #     ) do |s|
              #       s.path(
              #         stroke: "currentColor",
              #         stroke_linecap: "round",
              #         stroke_linejoin: "round",
              #         stroke_width: "2",
              #         d: "m1 1 4 4 4-4"
              #       )
              #     end
              #   end
              # end
            end
          end

          private

          def current_scope = resource_query_params[:scope]

          def render?
            current_query_object.scope_definitions.present?
          end
        end
      end
    end
  end
end
