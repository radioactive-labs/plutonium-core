# frozen_string_literal: true

module Plutonium
  module Wizard
    # Decorates a step's typed `data` so ATTACHMENT fields READ as resolved,
    # displayable attachments ({Attachments::Resolved}) rather than the raw staged
    # token string — so the step form's `Uppy` preview rehydrates on Back/resume
    # (it calls `.url`/`.signed_id`/`.filename`, which a bare token string can't
    # answer). Every other field delegates unchanged.
    #
    # Read-only: the SUBMITTED value is still the token the hidden preview field
    # re-posts (`Resolved#signed_id` == the original token), so staging is
    # unaffected.
    class AttachmentData < SimpleDelegator
      # Wrap only when the step actually has an attachment field — otherwise return
      # the data untouched, so the overwhelming majority of steps are unaffected.
      def self.wrap(data, step)
        attachment_fields = step.inputs.select { |_name, config| Attachments.field?(config) }
        attachment_fields.any? ? new(data, attachment_fields) : data
      end

      def initialize(data, attachment_fields)
        super(data)
        attachment_fields.each do |name, config|
          multiple = config.dig(:options, :multiple)
          define_singleton_method(name) do
            resolved = Attachments.resolve(__getobj__.public_send(name))
            multiple ? resolved : resolved.first
          end
        end
      end

      # Masquerade as the wrapped object's class so phlexi still infers field
      # affordances (required marker, maxlength, …) from its validators — it reads
      # `object.class.validators_on(...)`, and a `SimpleDelegator` would otherwise
      # report its own class and drop every marker on the step.
      def class
        __getobj__.class
      end
    end
  end
end
