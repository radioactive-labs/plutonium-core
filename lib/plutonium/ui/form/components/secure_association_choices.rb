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
              # The wrapper's <label for=> points at this id, but a label can't
              # name a div, so the group carries the field label itself.
              div(id: attributes[:id], class: attributes[:class], role: group_role, aria_label: field.label) do
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
                "associations (#{association_name}). Supported: #{supported_macros.join(", ")}."
            end

            if association_reflection.polymorphic?
              raise ArgumentError, "#{self.class.name.demodulize} does not support polymorphic associations (#{association_name})."
            end
          end

          def association_name = "#{field.object.class.name}##{association_reflection.name}"

          def build_attributes
            super
            if @group_method
              raise ArgumentError, "#{self.class.name.demodulize} does not support group_method: (#{association_name})."
            end

            # Typeahead drives a slim-select dropdown; a rendered list has no
            # search box to wire it to.
            @typeahead_option = false
          end

          # Capped like the select (`choice_limit:`, DEFAULT_CHOICE_LIMIT by
          # default), but the selected records always render: an unrendered
          # checkbox is not submitted, so saving the form would drop it.
          def choices
            @choices ||= begin
              collection = @raw_choices || authorized_relation
              if @choice_limit && collection.respond_to?(:limit)
                collection = (collection.limit(@choice_limit).to_a + collection.where(id: selected_record_ids).to_a).uniq
              end
              build_choice_mapper(collection)
            end
          end

          # Every option renders, so compare against the selection once per
          # option instead of re-parsing it for every selected record.
          def selected?(option)
            selected_gids.include?(SignedGlobalID.parse(option)&.uri&.to_s)
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

          def selected_gids
            @selected_gids ||= Array(singular? ? singular_field_value : collection_field_value).compact.to_set { |sgid| sgid.uri.to_s }
          end

          def selected_record_ids
            Array(field.object.public_send(association_reflection.name)).map(&:id)
          end

          def singular? = %i[belongs_to has_one].include?(association_reflection.macro)

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
