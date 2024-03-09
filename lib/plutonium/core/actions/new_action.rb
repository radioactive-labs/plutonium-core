module Plutonium
  module Core
    module Actions
      class NewAction < BasicAction
        private

        def action_options
          {
            icon: "plus",
            route_options: Plutonium::Core::Action::RouteOptions.new(action: :new),
            action_class: "primary",
            collection_action: true
          }
        end
      end
    end
  end
end
