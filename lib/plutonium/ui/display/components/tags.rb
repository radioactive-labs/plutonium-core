# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # A no_fly_list `has_tags` context as chips. Reads the tag records
        # through the context's association, so a table can preload it
        # (`includes(:labels)`) to avoid a query per row.
        class Tags < List
          private

          def normalize_value(value) = value.map(&:name)
        end
      end
    end
  end
end
