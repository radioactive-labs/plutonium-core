module Plutonium
  module Helpers
    module ActionButtonsHelper
      def generic_action_button(url, label:, icon:, button_class:, method:, confirm:, turbo_frame:)
        if method == :get
          resource_component :button, to: url, icon:, label:, size: :xs, color: button_class.to_sym, data: {turbo_frame:}
        else
          form_for :action, url:, method:, turbo_frame:, html: {class: "", data: {turbo_confirm: confirm}} do
            resource_component :button, icon:, label:, size: :xs, color: button_class.to_sym
          end
        end
      end

      def toolbar_action_button(url, label:, icon:, button_class: nil, method: :get, confirm: nil, turbo_frame: nil)
        generic_action_button(url, label:, icon:, button_class:, method:, confirm:, turbo_frame:)
      end

      def table_action_button(url, label:, icon:, button_class: nil, method: :get, confirm: nil, turbo_frame: nil)
        generic_action_button(url, label:, icon: nil, button_class:, method:, confirm:, turbo_frame:)
      end
    end
  end
end
