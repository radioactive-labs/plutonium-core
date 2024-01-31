module Plutonium
  module Core
    module UI
      Form = Data.define :record, :inputs do
        def initialize(record: nil, inputs: {})
          super
        end
      end
    end
  end
end
