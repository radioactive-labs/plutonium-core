module Plutonium
  module UI
    module Builder
      class Form
        include Pu::UI::Concerns::DefinesInputs

        attr_reader :record

        def initialize(model_class)
          initialize_inputs_definer(model_class)
        end

        def with_record(record)
          @record = record
          self
        end
      end
    end
  end
end
