module Plutonium
  module Core
    module Actions
      class DestroyAction < BasicAction
        def collection_record_action?
          true
        end

        def record_action?
          true
        end

        private

        def action_options
          {
            icon: "trash",
            route_options: Plutonium::Core::Action::RouteOptions.new(method: :delete),
            action_class: "danger",
            confirmation: "Are you sure?",
            turbo_frame: "_top"
          }
        end
      end
    end
  end
end
