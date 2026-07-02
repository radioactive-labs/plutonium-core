# frozen_string_literal: true

module Plutonium
  module UI
    module Wizard
      # A tiny read-only display over the wizard's typed `data` snapshot, used by
      # the review step's auto-summary (§2.5). Reuses the Plutonium display
      # pipeline (`Display::Base` + its inferred-type builder + `field(...).wrapped`)
      # so each field's label and value formatting match the rest of the app,
      # rather than re-implementing value rendering.
      class SummaryDisplay < Plutonium::UI::Display::Base
        # @param object [Object] the wizard `data` snapshot.
        # @param fields [Array<Symbol>] scalar field names to summarize.
        # @param inputs [Hash] the step's input config ({name => {options:}}), so a
        #   field's declared `as:` informs the display component (e.g. a `:text`
        #   input renders via the markdown/text display tag).
        def initialize(object, fields:, inputs: {}, **options)
          options[:key] = :wizard
          @summary_fields = fields
          @summary_inputs = inputs
          super(object, **options)
        end

        def display_template
          dl(class: "grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-3") do
            @summary_fields.each { |name| render_summary_field(name) }
          end
        end

        private

        def render_summary_field(name)
          input_options = @summary_inputs[name]&.dig(:options) || {}
          field_options = input_options[:label] ? {label: input_options[:label]} : {}

          # A currency input stages a plain decimal; the data snapshot carries no
          # has_cents reflection, so inference would render it as a bare number.
          # Force the currency display and thread the declared `unit:` so the
          # recap reads "$1,234.56", matching the input's prefix.
          if input_options[:as]&.to_sym == :currency
            return render field(name, **field_options).wrapped { |f|
              render f.send(:create_component, Plutonium::UI::Display::Components::Currency, :currency, unit: input_options[:unit])
            }
          end

          # A choice input (select/radio_buttons) stages the raw value; its
          # value -> label map lives only in `choices:`. Resolve it and render the
          # label as a string, rather than inferring a plain-string tag off the
          # raw value (which would show "female" instead of "Female").
          if input_options[:choices]
            label = resolve_choice_label(name, input_options)
            return render field(name, value: label, **field_options).wrapped { |f| render f.string_tag }
          end

          render field(name, **field_options).wrapped do |f|
            render instance_exec(f, &summary_tag_block(name))
          end
        end

        # Map the raw value(s) to their choice label(s) using the SAME mapper the
        # form's select uses, so summary labels always match the form. Falls back
        # to the raw value for anything not in `choices:`; nil for an empty field
        # (so the display renders its placeholder).
        def resolve_choice_label(name, input_options)
          mapper = Phlexi::Form::SimpleChoicesMapper.new(
            input_options[:choices],
            label_method: input_options[:label_method],
            value_method: input_options[:value_method]
          )
          raw = Phlexi::Field::Support::Value.from(object, name)
          Array(raw).map { |value| mapper[value] || value }.join(", ").presence
        end

        # Pick the display component the same way a resource display does — infer it
        # from the value's TYPE (date, boolean, number, currency, …) instead of
        # stringifying everything. The one override: an attachment field stages a
        # string TOKEN, so inference can't tell it's an attachment — force it (the
        # data object is decorated upstream to resolve the token to an attachment).
        def summary_tag_block(name)
          ->(f) {
            tag = Plutonium::Wizard::Attachments.field?(@summary_inputs[name]) ? :attachment : f.inferred_field_component
            if tag.is_a?(Class)
              f.send(:create_component, tag, tag.name.demodulize.underscore.sub(/component$/, "").to_sym)
            else
              f.send(:"#{tag}_tag")
            end
          }
        end
      end
    end
  end
end
