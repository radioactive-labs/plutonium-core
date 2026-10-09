# frozen_string_literal: true

module Plutonium
  module UI
    module Options
      # Detects `has_rich_text` fields by the `rich_text_<name>` association
      # Action Text defines. phlexi-field stopped inferring :rich_text, so
      # without this they fall through to a plain string.
      module RichTextField
        private

        def rich_text_field?
          object.is_a?(ActiveRecord::Base) && object.class.reflect_on_association(:"rich_text_#{key}").present?
        end
      end
    end
  end
end
