module Plutonium
  module UI
    module Builder
      class Form
        attr_reader :record, :inputs

        def with_inputs(inputs)
          @inputs = inputs
          self
        end

        def with_record(record)
          @record = record
          self
        end
      end
    end
  end
end
