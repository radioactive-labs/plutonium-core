module Plutonium
  module Core
    module Actions
      class NewAction < BasicAction
        def collection_action?
          true
        end

        private

        def action_options
          {
            icon: "plus-lg",
            route_options: Plutonium::Core::Action::RouteOptions.new(action: :new),
            action_class: "primary"
          }
        end
      end
    end
  end
end
