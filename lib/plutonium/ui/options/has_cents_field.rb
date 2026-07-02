# frozen_string_literal: true

module Plutonium
  module UI
    module Options
      # Shared detector for a `has_cents` money field, so the form and display
      # inferred-type chains agree on what counts as currency (an explicit
      # `as: :currency` is never needed for a `has_cents` attribute). Included
      # into both `Form::Options::InferredTypes` and `Display::Options::InferredTypes`.
      module HasCentsField
        private

        # Whether the field being rendered is a `has_cents` decimal accessor.
        def has_cents_field?
          klass = object.class
          klass.respond_to?(:has_cents_decimal_attribute?) && klass.has_cents_decimal_attribute?(key)
        end
      end
    end
  end
end
