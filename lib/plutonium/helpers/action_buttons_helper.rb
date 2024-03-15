module Plutonium
  module Helpers
    module ActionButtonsHelper
      def toolbar_action_button(resource, action)
        render_component :action_button,
          classname: "me-2",
          to: resource_url_for(resource, action: action.route_options.action, **action.route_options.options),
          method: action.route_options.method,
          icon: action.icon,
          label: action.label,
          tooltip: action.label,
          color: action.color,
          confirmation: action.confirmation,
          size: :xs
      end

      def table_action_button(resource, action)
        render_component :action_button,
          classname: "ms-2",
          to: resource_url_for(resource, action: action.route_options.action, **action.route_options.options),
          method: action.route_options.method,
          icon: action.icon,
          label: nil, # action.label,
          tooltip: action.label,
          color: action.color,
          confirmation: action.confirmation,
          variant: :outline,
          size: :xs
      end
    end
  end
end
