# frozen_string_literal: true

module Plutonium
  module Wizard
    # Decorates a step's typed `data` so fields declared with `choices:` read as
    # their human-readable label rather than the raw stored value (an integer id,
    # an enum key-string, etc.).
    #
    # The wizard DSL lets authors write:
    #
    #   input :member_id, as: :slim_select,
    #     choices: -> { Member.all.map { |m| [m.name, m.id] } }
    #
    #   input :payment_method, as: :slim_select,
    #     choices: {cash: "Cash", cheque: "Cheque"}
    #
    # On the review page the raw stored value (`42`, `"cash"`) would otherwise be
    # shown; this decorator intercepts the getter and returns the label the form's
    # own `<option>` carried. Every other field delegates unchanged.
    #
    # Resolution is delegated to `Phlexi::Form::SimpleChoicesMapper` — the SAME
    # class the select input materialises its options with — so the review page and
    # the form can never disagree about which label belongs to a value. That also
    # means every collection shape the form accepts works here for free: arrays of
    # `[label, value]` pairs, `{value => label}` hashes, ranges, sets, ActiveRecord
    # relations and record arrays (mapped via `id`/`to_label`/`name`/`title`), and
    # procs returning any of those. `label_method:`/`value_method:` are honoured
    # alongside `choices:`, exactly as the input honours them.
    #
    # NOTE: only the declarative `choices:` OPTION is resolvable. Choices supplied
    # inside a block (`input(:x) { |f| f.select_tag choices: ... }`) are invisible
    # here — they're computed during form render, not stored on the step — so those
    # fields still display their raw value.
    #
    # Read-only decoration — submitted values are unchanged.
    class ChoicesData < SimpleDelegator
      # Wrap only when the step actually declares fields with a `choices:` option.
      # Returns the raw data object when there's nothing to do.
      def self.wrap(data, step)
        choice_fields = step.inputs.select { |_name, config| config.dig(:options, :choices) }
        choice_fields.any? ? new(data, choice_fields) : data
      end

      def initialize(data, choice_fields)
        super(data)
        choice_fields.each do |name, config|
          options = config[:options]
          define_singleton_method(name) do
            resolve_label(options, __getobj__.public_send(name))
          end
        end
      end

      # Masquerade as the wrapped object's class so Phlexi still infers field
      # affordances (required marker, maxlength, etc.) from the real validators.
      def class
        __getobj__.class
      end

      private

      # @return [String, Array<String>, nil] the label for +raw_value+, or the raw
      #   value stringified when the choices list doesn't contain it.
      def resolve_label(options, raw_value)
        return raw_value if raw_value.nil?

        # A multi-select stores an array; label each element so the display renders
        # the labels rather than the inspected array.
        return raw_value.map { |value| resolve_label(options, value) } if raw_value.is_a?(Array)
        return raw_value.to_s if raw_value.to_s.empty?

        mapper = Phlexi::Form::SimpleChoicesMapper.new(
          options[:choices],
          label_method: options[:label_method],
          value_method: options[:value_method]
        )
        mapper[raw_value] || raw_value.to_s
      rescue => e
        Rails.logger.warn { "[Plutonium::Wizard] ChoicesData could not resolve a label: #{e.message}" }
        raw_value.to_s
      end
    end
  end
end
