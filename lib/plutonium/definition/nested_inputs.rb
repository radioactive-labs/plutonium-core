module Plutonium
  module Definition
    module NestedInputs
      extend ActiveSupport::Concern

      included do
        defineable_prop :nested_input
      end
    end
  end
end
