# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Concerns
        # Shared sizing + chrome for repeater-style field groups. Both
        # RendersNestedResourceFields and RendersStructuredInputs render the
        # same fieldset/grid markup and share a default row limit, so the
        # values live here to keep the two concerns from drifting apart.
        module RepeaterFieldStyles
          # Default maximum number of rows a repeater renders/clones.
          DEFAULT_LIMIT = 10

          # Outer fieldset chrome for a single repeater row.
          FIELDSET_CLASS = "nested-resource-form-fields border border-[var(--pu-border)] rounded-[var(--pu-radius-md)] p-4 space-y-4 relative"

          # Responsive grid the row's fields are laid out in.
          FIELD_GRID_CLASS = "grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-4 grid-flow-row-dense"
        end
      end
    end
  end
end
