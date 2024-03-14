module Plutonium
  module Core
    module Actions
      class NewAction < BasicAction
        private

        def action_options
          {
            icon: "outline/general/plus",
            route_options: Plutonium::Core::Action::RouteOptions.new(action: :new),
            color: :primary,
            collection_action: true
          }
        end
      end
    end
  end
end
