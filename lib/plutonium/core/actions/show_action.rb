module Plutonium
  module Core
    module Actions
      class ShowAction < BasicAction
        private

        def action_options
          {
            icon: "outline/general/arrow-up-right-from-square",
            color: :primary,
            collection_record_action: true
          }
        end
      end
    end
  end
end
