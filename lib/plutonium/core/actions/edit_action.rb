module Plutonium
  module Core
    module Actions
      class EditAction < BasicAction
        private

        def action_options
          {
            icon: "outline/edit",
            route_options: Plutonium::Core::Action::RouteOptions.new(action: :edit),
            color: :yellow,
            collection_record_action: true,
            record_action: true,
            category: :standard,
            position: 20
          }
        end
      end
    end
  end
end
