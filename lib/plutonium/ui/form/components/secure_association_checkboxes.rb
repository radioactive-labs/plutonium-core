# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # A has_many / habtm association rendered as one checkbox per authorized
        # record (`input :tags, as: :association_checkboxes`).
        class SecureAssociationCheckboxes < SecureAssociationChoices
          protected

          def control_type = :checkbox

          def control_theme = :association_checkbox

          def supported_macros = %i[has_many has_and_belongs_to_many]

          # Unchecked boxes are not submitted, so without this blank value
          # clearing every box would leave the param out entirely and keep the
          # existing records. The blank is dropped by normalize_array_input.
          def render_hidden_input
            input(type: :hidden, name: attributes[:name], value: "", autocomplete: "off", hidden: true)
          end
        end
      end
    end
  end
end
