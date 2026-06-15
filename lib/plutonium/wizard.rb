# frozen_string_literal: true

require_relative "wizard/errors"
require_relative "wizard/configuration"

module Plutonium
  # The Plutonium wizard subsystem: multi-step, DB-backed, data-capture wizards.
  module Wizard
    # The union `data` schema (§2.6) and the runner's inline validator both build
    # anonymous ActiveModel classes from a step's `attribute_schema`. A `using:`
    # import contributes the model's column types (e.g. `:text`), which
    # ActiveModel's type registry doesn't know. Fall back to `:string` for any type
    # the registry can't resolve so the snapshot/validator still builds — the
    # staged value is stored/displayed as-is.
    def self.safe_attribute_type(type)
      ActiveModel::Type.lookup(type)
      type
    rescue ArgumentError
      :string
    end
  end
end
