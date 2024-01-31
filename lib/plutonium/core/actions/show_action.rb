module Plutonium
  module Core
    module Actions
      class ShowAction < BasicAction
        def collection_record_action?
          true
        end

        private

        def action_options
          {
            icon: "box-arrow-up-right",
            action_class: "primary"
          }
        end
      end
    end
  end
end
