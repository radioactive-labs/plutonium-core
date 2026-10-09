# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # File input for a `binary` column: the uploaded file's bytes become
        # the value. Choosing no file extracts nil, which the resource
        # controller compacts away, so an edit that doesn't replace the file
        # keeps the stored bytes. There is no way to clear the column here.
        class Binary < Phlexi::Form::Components::FileInput
          protected

          def build_input_attributes
            super
            apply_default_hint
          end

          def normalize_input(input_value)
            input_value.read if input_value.is_a?(ActionDispatch::Http::UploadedFile)
          end

          private

          # Says what a blank submit keeps: the bytes in the database, not a
          # rejected upload still assigned to the record on a failed re-render.
          def apply_default_hint
            return if field.has_hint?

            stored = field.object.attribute_in_database(field.key) if field.object.persisted?
            return if stored.blank?

            size = ActiveSupport::NumberHelper.number_to_human_size(stored.bytesize)
            field.hint(Plutonium::Translation.t("plutonium.ui.form.binary.replace_hint", size:))
          end
        end
      end
    end
  end
end
