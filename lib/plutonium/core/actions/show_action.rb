module Plutonium
  module Core
    module Actions
      class ShowAction < BasicAction
        private

        def action_options
          {
            icon: "outline/general/arrow-up-right-from-square",
            color: :primary,
            collection_record_action: true,
            category: :standard,
            position: 10
          }
        end
      end
    end
  end
end
