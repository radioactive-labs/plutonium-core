module Plutonium
  module Core
    module Actions
      class ShowAction < BasicAction
        private

        def action_options
          {
            icon: "box-arrow-up-right",
            action_class: "primary",
            collection_record_action: true,
          }
        end
      end
    end
  end
end
