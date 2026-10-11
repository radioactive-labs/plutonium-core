# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # Abstract base for the list-style association inputs: every choice is
        # rendered as its own control (checkbox, toggle or radio button) instead
        # of an option inside a slim-select.
        #
        # Everything that makes the association input "secure" is inherited from
        # {SecureAssociation} unchanged: the choices come from the policy-scoped
        # relation (or `choices:`), each value is a signed global id, submitted
        # ids are validated against the authorized relation, and the inline "+"
        # add button still renders. Only the markup differs.
        #
        # Subclasses declare the control's input type, the macros they accept and
        # the theme key their controls style off.
        class SecureAssociationChoices < SecureAssociation
          def view_template
            div(class: "flex items-start space-x-1") do
              div(id: attributes[:id], class: attributes[:class], role: group_role) do
                render_hidden_input
                render_blank_choice if include_blank?
                render_choices
              end
              render_add_button
            end
          end

          protected

          # The type attribute of each control: "checkbox" or "radio".
          def control_type = raise(NotImplementedError, "#{self.class}#control_type")

          # Theme key the individual controls style off.
          def control_theme = raise(NotImplementedError, "#{self.class}#control_theme")

          # Association macros this variant can represent.
          def supported_macros = raise(NotImplementedError, "#{self.class}#supported_macros")

          def group_role = "group"

          def build_association_attributes
            super

            unless supported_macros.include?(association_reflection.macro)
              raise ArgumentError,
                "#{self.class.name.demodulize} does not support #{association_reflection.macro} " \
                "associations (#{field.object.class.name}##{association_reflection.name}). " \
                "Supported: #{supported_macros.join(", ")}."
            end
          end

          def build_attributes
            # No default cap: a selected record past the limit would not render,
            # so saving the form would silently drop it. Pass `choice_limit:` to
            # opt back in.
            attributes[:choice_limit] = nil unless attributes.key?(:choice_limit)
            super
            # Typeahead drives a slim-select dropdown; a rendered list has no
            # search box to wire it to.
            @typeahead_option = false
          end

          def render_choices
            if choices.values.empty?
              p(class: "pu-hint") { Plutonium::Translation.t("plutonium.ui.form.association_choices.empty") }
              return
            end

            choices.each.with_index do |(value, text), index|
              render_choice(value:, text:, id: "#{attributes[:id]}_#{index}", checked: selected?(value))
            end
          end

          def render_choice(value:, text:, id:, checked:)
            label(for: id, class: themed(:association_choice_label, field)) do
              input(
                type: control_type,
                id:,
                name: attributes[:name],
                value:,
                checked:,
                required: control_required?,
                disabled: attributes[:disabled],
                class: themed(control_theme, field)
              )
              span { text }
            end
          end

          def render_hidden_input
          end

          def render_blank_choice
          end

          def include_blank? = false

          def control_required? = false
        end
      end
    end
  end
end
