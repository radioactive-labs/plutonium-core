module Plutonium
  module Definition
    module NestedInputs
      extend ActiveSupport::Concern

      included do
        defineable_prop :nested_input

        # def self.nested_input(name, with: nil, **)
        #   defined_nested_inputs[name] = {}
        # end

        # def nested_input(name, with: nil, **)
        #   instance_defined_nested_inputs[name] = {}
        # end
      end
    end
  end
end
