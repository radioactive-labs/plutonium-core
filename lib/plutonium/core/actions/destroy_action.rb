module Plutonium
  module Core
    module Actions
      class DestroyAction < BasicAction
        private

        def action_options
          {
            icon: "outline/general/trash-bin",
            route_options: Plutonium::Core::Action::RouteOptions.new(method: :delete),
            color: :red,
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
