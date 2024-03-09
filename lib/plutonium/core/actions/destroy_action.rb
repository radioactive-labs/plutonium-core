module Plutonium
  module Core
    module Actions
      class DestroyAction < BasicAction
        private

        def action_options
          {
            icon: "trash",
            route_options: Plutonium::Core::Action::RouteOptions.new(method: :delete),
            action_class: "red",
            confirmation: "Are you sure?",
            turbo_frame: "_top",
            collection_record_action: true,
            record_action: true
          }
        end
      end
    end
  end
end
