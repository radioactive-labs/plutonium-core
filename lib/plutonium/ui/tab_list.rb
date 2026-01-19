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
          data_controller: "resource-tab-list",
          data_resource_tab_list_active_classes_value: "focus:outline-none text-primary-600 border-primary-600 dark:text-primary-400 dark:border-primary-400",
          data_resource_tab_list_in_active_classes_value: "text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] border-transparent hover:border-[var(--pu-border-strong)]"
        ) do
          div(class: "mb-6 border-b border-[var(--pu-border)]") do
            ul(
              class: "flex flex-wrap -mb-px text-base font-semibold text-center gap-1",
              role: "tablist"
            ) do
              @tabs.each do |tab|
                li(role: "presentation") do
                  button(
                    class: "inline-block px-5 py-3 border-b-2 rounded-t-lg transition-colors",
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
