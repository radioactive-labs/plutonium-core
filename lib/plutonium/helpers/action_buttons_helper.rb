module Plutonium
  module Helpers
    module ActionButtonsHelper
      def toolbar_action_button(url, label:, icon:, color: nil, method: :get, confirm: nil, turbo_frame: nil)
        resource_component :action_button, to: url, method:, icon:, label:, size: :xs, color:, turbo_frame:, confirmation: confirm
      end

      def table_action_button(url, label:, icon:, color: nil, method: :get, confirm: nil, turbo_frame: nil)
        resource_component :action_button, to: url, method:, icon:, variant: :outline, label:, size: :xs, color:, turbo_frame:, confirmation: confirm
      end
    end
  end
end
