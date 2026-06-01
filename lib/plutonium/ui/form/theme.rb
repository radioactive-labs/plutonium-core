# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Theme < Phlexi::Form::Theme
        def self.theme
          super.merge({
            # Form structure
            base: "pu-card my-4 p-8 space-y-8",
            fields_wrapper: "grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-6 grid-flow-row-dense",
            actions_wrapper: "flex justify-end gap-3 pt-4 border-t border-[var(--pu-border-muted)]",
            wrapper: nil,
            inner_wrapper: "w-full",

            # Form errors
            form_errors_wrapper: "flex items-start gap-3 m-4 p-4 text-base text-danger-800 rounded-[var(--pu-radius-lg)] bg-danger-50 border border-danger-200 dark:bg-danger-950/30 dark:border-danger-800 dark:text-danger-300",
            form_errors_message: "font-semibold",
            form_errors_list: "mt-2 list-disc list-inside text-sm",

            # Label themes
            # The required marker is a `<abbr title="required">*</abbr>` which
            # picks up the browser's default dotted underline — strip it and
            # color the asterisk as a danger indicator instead.
            label: "mt-2 block mb-2 text-base font-semibold [&_abbr]:no-underline [&_abbr]:border-0 [&_abbr]:cursor-default [&_abbr]:text-danger-500",
            invalid_label: "text-danger-700 dark:text-danger-400",
            valid_label: "text-success-700 dark:text-success-400",
            neutral_label: "text-[var(--pu-text)]",

            # Input themes
            input: "pu-input",
            invalid_input: "pu-input pu-input-invalid",
            valid_input: "pu-input pu-input-valid",
            neutral_input: "",

            # Checkbox / Boolean
            checkbox: "pu-checkbox",
            boolean: "pu-checkbox",
            valid_boolean: "pu-checkbox",
            invalid_boolean: "pu-checkbox pu-input-invalid",

            # Radio buttons
            radio_button: "pu-radio",
            collection_radio_buttons: "flex flex-col gap-2",

            # Color
            color: "pu-color-input appearance-none bg-transparent border-none cursor-pointer w-12 h-12 rounded-lg",
            invalid_color: nil,
            valid_color: nil,
            neutral_color: nil,

            # File input — keep pu-input's h-9 so the field matches the height
            # of text inputs and slim-selects. The native file-selector-button
            # fills the *full* height of the control and sits flush against the
            # left edge (px-0 on the wrapper, no vertical margin), reading as a
            # segmented button. A right border divides it from the filename text,
            # and only the left corners are rounded so it nests inside pu-input.
            # NOTE: pu-input ships its px-3/h-9 padding *unlayered*, so plain
            # pl-0/py-0 utilities (in @layer utilities) lose to it — the !
            # important variants are required to flatten the wrapper padding.
            file: "pu-input pl-0! py-0! [&::file-selector-button]:h-full [&::file-selector-button]:align-middle [&::file-selector-button]:m-0 [&::file-selector-button]:mr-4 [&::file-selector-button]:px-4 [&::file-selector-button]:leading-[1.1] [&::file-selector-button]:bg-[var(--pu-surface-alt)] [&::file-selector-button]:border-0 [&::file-selector-button]:border-r [&::file-selector-button]:border-[var(--pu-input-border)] [&::file-selector-button]:rounded-none [&::file-selector-button]:rounded-l-md [&::file-selector-button]:text-sm [&::file-selector-button]:font-semibold [&::file-selector-button]:text-[var(--pu-text-muted)] [&::file-selector-button]:hover:bg-[var(--pu-border)] [&::file-selector-button]:cursor-pointer [&::file-selector-button]:transition-colors",

            # Hint themes
            hint: "pu-hint whitespace-pre-wrap",

            # Error themes
            error: "text-xs text-danger-600 mt-1",

            # Button themes
            button: "pu-btn pu-btn-md pu-btn-primary",

            # Flatpickr
            flatpickr: :input,
            valid_flatpickr: :valid_input,
            invalid_flatpickr: :invalid_input,
            neutral_flatpickr: :neutral_input,

            # Int tel input
            int_tel_input: :input,
            valid_int_tel_input: :valid_input,
            invalid_int_tel_input: :invalid_input,
            neutral_int_tel_input: :neutral_input,

            # Uppy file upload
            uppy: :file,
            valid_uppy: :valid_file,
            invalid_uppy: :invalid_file,
            neutral_uppy: :neutral_file,

            # Association
            association: :select,
            valid_association: :valid_select,
            invalid_association: :invalid_select,
            neutral_association: :neutral_select,

            # Polymorphic association
            polymorpic_association: :association,
            valid_polymorpic_association: :valid_association,
            invalid_polymorpic_association: :invalid_association,
            neutral_polymorpic_association: :neutral_association
          })
        end
      end
    end
  end
end
