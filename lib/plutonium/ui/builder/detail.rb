module Plutonium
  module UI
    module Builder
      class Detail
        attr_reader :record, :actions, :fields

        delegate :to_partial_path, to: :record

        def initialize(model_class)
        end

        def with_fields(fields)
          @fields = fields
          self
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
