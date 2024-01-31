module Plutonium
  module Core
    module Actions
      class EditAction < BasicAction
        def collection_record_action?
          true
        end

        def record_action?
          true
        end

        private

        def action_options
          {
            icon: "pencil",
            route_options: Plutonium::Core::Action::RouteOptions.new(action: :edit),
            action_class: "warning"
          }
        end
      end
    end
  end
end
