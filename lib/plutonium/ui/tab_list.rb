module Plutonium
  module UI
    class TabList < Plutonium::UI::Component::Base
      class TabDefinition
      end

      BASE_BUTTON_CLASSES = "inline-block px-5 py-3 border-b-2 rounded-t-lg transition-colors"
      ACTIVE_CLASSES = "focus:outline-none text-primary-600 border-primary-600 dark:text-primary-400 dark:border-primary-400"
      INACTIVE_CLASSES = "text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] border-transparent hover:border-[var(--pu-border-strong)]"

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
        default_identifier = @tabs.first&.dig(:identifier)

        div(
          data_controller: "resource-tab-list",
          data_resource_tab_list_active_classes_value: ACTIVE_CLASSES,
          data_resource_tab_list_in_active_classes_value: INACTIVE_CLASSES
        ) do
          div(class: "mb-6 border-b border-[var(--pu-border)]") do
            ul(
              class: "flex flex-wrap -mb-px text-base font-semibold text-center gap-1",
              role: "tablist"
            ) do
              @tabs.each do |tab|
                active = tab[:identifier] == default_identifier
                li(role: "presentation") do
                  button(
                    class: button_classes_for(active),
                    id: "#{tab[:identifier]}-tab",
                    type: "button",
                    role: "tab",
                    aria_controls: "#{tab[:identifier]}-tabpanel",
                    aria_selected: active.to_s,
                    tabindex: active ? "0" : "-1",
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
              active = tab[:identifier] == default_identifier
              div(
                hidden: !active,
                id: "#{tab[:identifier]}-tabpanel",
                role: "tabpanel",
                aria_labelledby: "#{tab[:identifier]}-tab",
                aria_hidden: (!active).to_s,
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

      private

      def button_classes_for(active)
        "#{BASE_BUTTON_CLASSES} #{active ? ACTIVE_CLASSES : INACTIVE_CLASSES}"
      end
    end
  end
end
