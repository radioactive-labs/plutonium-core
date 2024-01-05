module Plutonium
  module Helpers
    module ActionButtonsHelper
      def generic_action_button(url, icon:, button_class:, method:, confirm:, turbo_frame:)
        if method == :get
          link_to url, class: button_class, data: {turbo_frame:} do
            tag.i class: "bi bi-#{icon}"
          end
        else
          form_for :action, url:, method:, turbo_frame:,
            html: {class: "d-inline-block", data: {turbo_confirm: confirm}} do
            tag.button class: button_class do
              tag.i class: "bi bi-#{icon}"
            end
          end
        end
      end

      def toolbar_action_button(url, icon:, button_class: "secondary", method: :get, confirm: nil, turbo_frame: nil)
        button_class = "btn btn-sm btn-outline-#{button_class} toolbar-action-button"

        generic_action_button(url, icon:, button_class:, method:, confirm:, turbo_frame:)
      end

      def table_action_button(url, icon:, button_class: "secondary", method: :get, confirm: nil, turbo_frame: nil)
        button_class = "btn btn-sm btn-link text-#{button_class}"

        generic_action_button(url, icon:, button_class:, method:, confirm:, turbo_frame:)
      end
    end
  end
end
