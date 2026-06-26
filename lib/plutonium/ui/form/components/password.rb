# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # Password / secret input that never emits the stored value into the DOM.
        #
        # The generic Phlexi input renders `value=field.dom.value`, leaking the
        # server-side secret (and its length) into the page source. This component
        # instead renders a fixed SENTINEL whenever an *untouched* secret is
        # stored, masking both the secret and its length, and renders an empty
        # field otherwise.
        #
        # On submit the sentinel maps back to `nil`, which Plutonium's param
        # extraction (`submitted_resource_params`) compacts away — leaving the
        # stored value untouched. An empty field passes through as "":
        #
        #   untouched field → sentinel submitted → nil   → keep existing
        #   emptied field   → "" submitted       → ""    → explicit clear (clear-by-blank)
        #   typed value     → value submitted    → value → set new value
        #
        # On a failed re-render of an *edited* secret the field comes back blank
        # (we never echo a submitted secret). When the edit set a new value it is
        # also marked `required`, so the browser forces a re-type rather than a
        # silent blank resubmit clearing the stored secret. When the edit *cleared*
        # the value we leave it blank and not required — the clear may be intended
        # (clear-by-blank). Either guard is client-side UX only.
        #
        # The rendered sentinel is guarded client-side by the `password-sentinel`
        # Stimulus controller: the first edit (keystroke, paste, backspace) wipes
        # the whole field, so a partial edit can't corrupt the sentinel into a
        # literal new password.
        #
        # New records and interaction forms (set-password, reset-password) render
        # an honest empty field that invites input and lets password managers
        # offer to generate a strong password.
        class Password < Phlexi::Form::Components::Input
          # Rendered in place of an existing secret. Masked in the UI; only ever
          # visible (as this constant) in page source — never the real value.
          SENTINEL = "__plutonium_password_unchanged__"

          protected

          def build_input_attributes
            super
            attributes[:type] = :password
            value = masked_value
            attributes[:value] = value
            attributes[:autocomplete] ||= "new-password"
            # A stored secret edited (to a new value) on a failed submit comes
            # back blank. Force re-entry so an untouched resubmit can't silently
            # clear it via the clear-by-blank path. Client-side UX guard only.
            attributes[:required] = true if reentry_required?

            # When the field renders the sentinel, guard it so the first edit
            # wipes the whole value — a partial edit would corrupt the sentinel
            # into a literal new password.
            if value == SENTINEL
              attributes[:data_controller] = tokens(attributes[:data_controller], :"password-sentinel")
              attributes[:data_action] = tokens(attributes[:data_action], "beforeinput->password-sentinel#beforeinput")
              attributes[:data_password_sentinel_sentinel_value] = SENTINEL
            end

            apply_default_hint(value)
          end

          # The masked field is otherwise opaque — the user can't tell what the
          # dots mean or what a blank submit does. Supply a default hint
          # explaining it, unless the author already set one (theirs wins). The
          # wrapper renders the hint after this input, so setting it here is in
          # time. No hint for a plain empty field (new record) — it speaks for
          # itself.
          def apply_default_hint(value)
            return if field.has_hint?
            if value == SENTINEL
              field.hint("Leave blank to keep the current value.")
            elsif reentry_required?
              field.hint("Re-enter the new value to save it.")
            end
          end

          def masked_value
            key = field.key.to_s
            # New records and interaction forms (set-password, reset-password)
            # have nothing stored — render an empty field that invites input.
            return nil unless field.object.persisted?
            # Write-only attributes (e.g. has_secure_password's `password`) are
            # not real columns, so there is nothing stored to keep.
            return nil unless field.object.has_attribute?(key)
            # Nothing stored yet — render blank.
            return nil unless field.object.attribute_in_database(key).present?
            # A secret is stored. On a failed re-render of an edit it is dirty:
            # render blank so the user re-enters it (we never echo a submitted
            # secret). Otherwise mask it (and its length) behind the sentinel,
            # which submits back as "leave unchanged".
            field.object.attribute_changed?(key) ? nil : SENTINEL
          end

          # True only when a stored secret was edited *to a new value* and
          # therefore renders blank — the state where an untouched resubmit would
          # silently clear a secret the user meant to change. We deliberately do
          # NOT force re-entry when the edit blanked the value: that user may
          # have intended to clear it (clear-by-blank), so let the blank stand.
          def reentry_required?
            key = field.key.to_s
            field.object.persisted? &&
              field.object.has_attribute?(key) &&
              field.object.attribute_in_database(key).present? &&
              field.object.attribute_changed?(key) &&
              field.object.read_attribute(key).present?
          end

          def normalize_input(input_value)
            # The sentinel means "leave unchanged" → nil, which
            # `submitted_resource_params` compacts away so the stored secret is
            # kept. An empty field passes through as "" → an explicit clear
            # (clear-by-blank); a typed value is set as-is.
            return nil if input_value == SENTINEL
            super
          end
        end
      end
    end
  end
end
