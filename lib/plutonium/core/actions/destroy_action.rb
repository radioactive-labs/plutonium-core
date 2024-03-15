module Plutonium
  module Core
    module Actions
      class DestroyAction < BasicAction
        private

        def action_options
          {
            icon: "outline/trash-bin",
            route_options: Plutonium::Core::Action::RouteOptions.new(method: :delete),
            color: :red,
            confirmation: "Are you sure?",
            turbo_frame: "_top",
            collection_record_action: true,
            record_action: true,
            category: :standard,
            position: 100
          }
        end
      end
    end
  end
end
