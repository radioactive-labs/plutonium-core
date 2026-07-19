# frozen_string_literal: true

module Plutonium
  module Wizard
    # Decorates a step's typed `data` so SELECT/CHOICE fields read as their
    # resolved human-readable labels rather than the raw stored value (an
    # integer ID, an enum key-string, etc.).
    #
    # The wizard DSL lets authors write:
    #
    #   input :member_id, as: :slim_select,
    #     choices: -> { Member.all.map { |m| [m.name, m.id] } }
    #
    #   input :payment_method, as: :slim_select,
    #     choices: { cash: "Cash", cheque: "Cheque" }
    #
    # On the review page the raw stored value (e.g. `42` or `"cash"`) would be
    # shown; this decorator intercepts the getter and returns the matching label
    # from the choices list.  Every other field delegates unchanged.
    #
    # Choices can be:
    #   - Array of [label, value] pairs:  `[["Alice", 1], ["Bob", 2]]`
    #   - Hash {value => label}:          `{ cash: "Cash", cheque: "Cheque" }`
    #   - Hash {label => value}:          `{ "Cash" => :cash }` (resolved the same)
    #   - A Proc/Lambda returning any of the above (called lazily, once per field)
    #
    # Read-only decoration — submitted values are unchanged.
    class ChoicesData < SimpleDelegator
      # Wrap only when the step actually has fields with a `choices:` option.
      # Returns the raw data object when there's nothing to do.
      def self.wrap(data, step)
        choice_fields = step.inputs.select { |_name, config| config.dig(:options, :choices) }
        choice_fields.any? ? new(data, choice_fields) : data
      end

      def initialize(data, choice_fields)
        super(data)
        choice_fields.each do |name, config|
          raw_choices = config.dig(:options, :choices)
          define_singleton_method(name) do
            raw_value = __getobj__.public_send(name)
            resolve_label(raw_choices, raw_value)
          end
        end
      end

      # Masquerade as the wrapped object's class so Phlexi still infers field
      # affordances (required marker, maxlength, etc.) from the real validators.
      def class
        __getobj__.class
      end

      private

      # Resolve `raw_choices` to a label for `raw_value`.  Falls back to
      # `raw_value.to_s` when the value is not found in the choices list.
      def resolve_label(raw_choices, raw_value)
        return raw_value.to_s if raw_value.blank?

        choices = raw_choices.respond_to?(:call) ? raw_choices.call : raw_choices

        raw_str = raw_value.to_s

        case choices
        when Hash
          hit = choices.find { |k, _v| k.to_s == raw_str }
          hit ? hit[1].to_s : raw_value.to_s
        when Array
          normalized = choices.map { |item|
            arr = Array(item)
            (arr.size == 1) ? [arr[0].to_s, arr[0]] : arr
          }
          hit = normalized.find { |_label, val| val.to_s == raw_str }
          hit ? (hit[0].to_s) : raw_value.to_s
        else
          raw_value.to_s
        end
      rescue => e
        Rails.logger.warn { "[Plutonium::Wizard] ChoicesData resolve_label failed: #{e.message}" }
        raw_value.to_s
      end
    end
  end
end
