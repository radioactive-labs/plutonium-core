module Plutonium
  module UI
    class TabList < Plutonium::UI::Component::Base
      class TabDefinition
      end

      def initialize(...)
        super

        @tabs = []
      end

      def with_tab(identifier:, title:, &block)
        @tabs << {identifier:, title:, block:}
      end

      def render?
        @tabs.present?
      end

      def view_template
        div(
          class: theme_class(:tab, element: :list),
          data_controller: "resource-tab-list",
          data_resource_tab_list_active_classes_value: "focus:outline-none text-primary-600 hover:text-primary-600 dark:text-primary-500 dark:hover:text-primary-500 border-primary-600 dark:border-primary-500",
          data_resource_tab_list_in_active_classes_value: "dark:border-transparent text-gray-500 hover:text-gray-600 dark:text-gray-400 border-gray-100 hover:border-gray-300 dark:border-gray-700 dark:hover:text-gray-300"
        ) do
          div(class: "mb-md border-b border-gray-200 dark:border-gray-700") do
            ul(
              class: "flex flex-wrap -mb-px text-sm font-medium text-center space-x-sm",
              role: "tablist"
            ) do
              @tabs.each do |tab|
                li(role: "presentation") do
                  button(
                    class: tokens(theme_class(:tab, element: :button), "inline-block p-md border-b-2 rounded-t-lg"),
                    id: "#{tab[:identifier]}-tab",
                    type: "button",
                    role: "tab",
                    aria_controls: "#{tab[:identifier]}-tabpanel",
                    aria_selected: "false",
                    data_resource_tab_list_target: "btn",
                    data_target: "#{tab[:identifier]}-tabpanel",
                    data_action: "click->resource-tab-list#select"
                  ) do
                    phlexi_render tab[:title] do |val|
                      plain val
                    end
                  end
                end
              end
            end
          end

          div do
            @tabs.each do |tab|
              div(
                class: theme_class(:tab, element: :panel),
                hidden: true,
                id: "#{tab[:identifier]}-tabpanel",
                role: "tabpanel",
                aria_labelledby: "#{tab[:identifier]}-tab",
                data_resource_tab_list_target: "tab"
              ) do
                phlexi_render tab[:block] do |val|
                  raise NotImplementedError, "this should NEVER be triggered"
                end
              end
            end
          end
        end
      end
    end
  end
end
