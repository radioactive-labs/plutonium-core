# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # A belongs_to / has_one association rendered as one radio button per
        # authorized record (`input :category, as: :association_radio_buttons`).
        #
        # An optional association also gets a blank "None" choice, since a
        # radio group can't otherwise be cleared once something is picked.
        # `include_blank: false` drops it. A required association never gets
        # one: a checked "None" would satisfy the group's `required`.
        class SecureAssociationRadioButtons < SecureAssociationChoices
          protected

          def control_type = :radio

          def control_theme = :association_radio_button

          def supported_macros = %i[belongs_to has_one]

          def group_role = "radiogroup"

          def include_blank?
            return false if attributes[:required]

            @include_blank != false
          end

          # `required` on any radio in a group makes picking one of them required.
          def control_required? = attributes[:required]

          def render_blank_choice
            render_choice(value: "", text: blank_choice_text, id: "#{attributes[:id]}_blank", checked: singular_field_value.nil?)
          end

          def blank_choice_text
            field.placeholder.presence || Plutonium::Translation.t("plutonium.ui.form.association_choices.none")
          end
        end
      end
    end
  end
end
