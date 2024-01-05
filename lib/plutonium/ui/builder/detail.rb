module Plutonium
  module UI
    module Builder
      class Detail
        include Pu::UI::Concerns::DefinesFields

        attr_reader :record, :actions

        delegate :to_partial_path, to: :record

        def initialize(model_class)
          initialize_fields_definer(model_class)
        end

        def with_record(record)
          @record = record
          self
        end

        def with_actions(actions)
          @actions = actions
          self
        end
      end
    end
  end
end
