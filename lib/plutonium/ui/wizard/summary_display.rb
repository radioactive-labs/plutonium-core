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
        def initialize(object, fields:, inputs: {}, wizard: nil, **options)
          options[:key] = :wizard
          @summary_fields = fields
          @summary_inputs = inputs
          @wizard = wizard
          super(object, **options)
        end

        # The wizard driving this run. Present for the same reason the step form
        # exposes it: an `->(form) { form.wizard… }` option asks the form for it,
        # and on the review page this component stands in for the form.
        # @return [Plutonium::Wizard::Base, nil]
        attr_reader :wizard

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
          if Plutonium::Definition::InputAliases.resolve(input_options[:as]) == :currency
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
        # form's select uses, so summary labels always match the form. Falls back to
        # the raw value for anything not in `choices:`; nil for an empty field (so
        # the display renders its placeholder).
        #
        # The mapper is built ONCE per field, not once per value: `choices:` is
        # routinely a proc (`-> { Member.all.map { |m| [m.name, m.id] } }`), and a
        # per-value mapper would re-run that query for every element of a
        # multi-select.
        #
        def resolve_choice_label(name, input_options)
          values = Array(Phlexi::Field::Support::Value.from(object, name))
          return if values.empty?

          mapper = Phlexi::Form::SimpleChoicesMapper.new(
            resolved_choices(input_options[:choices]),
            label_method: input_options[:label_method],
            value_method: input_options[:value_method]
          )
          values.map { |value| mapper[value] || value }.join(", ").presence
        end

        # Resolve a proc'd `choices:` by the SAME arity rule the form applies to
        # every input option (see Form::Resource#call_option_proc): zero-arity means
        # what it reads like where it was written; `->(form) { … }` is asking for
        # the form, and on the review page this component stands in for it — it
        # answers `object` (the step's staged data) and `wizard`.
        #
        # Without this the summary hands the raw proc to the mapper, which bare-
        # `call`s it — so `choices: ->(form) { form.wizard.anchor.available_tiers }`,
        # a declaration Form::Wizard documents and the step form renders happily,
        # would raise ArgumentError the moment the user reached review.
        def resolved_choices(choices)
          return choices unless choices.is_a?(Proc)

          choices.arity.zero? ? choices.call : choices.call(self)
        end

        # Pick the display component the same way a resource display does — infer it
        # from the value's TYPE (date, boolean, number, currency, …) instead of
        # stringifying everything. The one override: an attachment field stages a
        # string TOKEN, so inference can't tell it's an attachment — force it (the
        # data object is decorated upstream to resolve the token to an attachment).
        def summary_tag_block(name)
          ->(f) {
            # nil lets the builder infer the tag from the value's type.
            tag = :attachment if Plutonium::Wizard::Attachments.field?(@summary_inputs[name])
            f.component_for(tag)
          }
        end
      end
    end
  end
end
