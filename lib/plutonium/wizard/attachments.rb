# frozen_string_literal: true

module Plutonium
  module Wizard
    # A wizard's view of {Plutonium::Attachments}.
    #
    # The staging and revival machinery moved out when async interactions needed
    # the same thing: both hold an attachment as a bare string while the work is
    # in flight, and neither has a model to hang it off until the work lands.
    # None of that was ever wizard-specific — only the two things left here are.
    #
    # This stays the wizard's entry point rather than having wizard code reach
    # for the shared module directly, so the +backend:+ default keeps being the
    # wizard's own setting without every call site remembering to pass it.
    module Attachments
      # Kept as a constant here because it is part of this module's published
      # surface: a host rendering a staged attachment may name
      # +Wizard::Attachments::Resolved+.
      Resolved = Plutonium::Attachments::Resolved

      module_function

      # Whether a step input renders as an attachment (its `as:` is a file alias),
      # so its staged token should be resolved for display. Keys off the form's
      # canonical file-input alias set, so the two never drift.
      #
      # Wizard-only: it reads a STEP INPUT's options, which is a shape nothing
      # outside the wizard DSL has.
      def field?(input_options)
        as = input_options&.dig(:options, :as) || input_options&.dig(:as)
        Plutonium::Definition::InputAliases.file_input?(as)
      end

      # The server-side staging backend for wizard attachments: the wizard's own
      # setting, else the global default.
      #
      # Layered rather than replacing: an app that sets only
      # +config.attachment_backend+ gets it here too, and one that sets
      # +config.wizards.attachment_backend+ still overrides it for wizards alone.
      #
      # @return [Symbol]
      def attachment_backend
        Plutonium.configuration.wizards.attachment_backend ||
          Plutonium::Attachments.default_backend
      end

      # @see Plutonium::Attachments.resolve
      def resolve(value) = Plutonium::Attachments.resolve(value)

      # @see Plutonium::Attachments.stage_upload
      def stage_upload(value, backend: nil, uploader: nil)
        Plutonium::Attachments.stage_upload(value, backend: backend || attachment_backend, uploader:)
      end

      # @see Plutonium::Attachments.validation_errors
      def validation_errors(value, backend: nil, uploader: nil)
        Plutonium::Attachments.validation_errors(value, backend: backend || attachment_backend, uploader:)
      end
    end
  end
end
