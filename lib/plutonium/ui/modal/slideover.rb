# frozen_string_literal: true

module Plutonium
  module UI
    module Modal
      class Slideover < Plutonium::UI::Modal::Base
        # Width tokens for each VALID_SIZES key. Mobile always takes
        # full width (the slideover is pinned to the right edge, so
        # anything narrower than the viewport looks awkward on phones);
        # the `sm:` token controls the desktop width. `:md` reproduces
        # the historical default. `:auto` switches to `sm:w-auto` with
        # a viewport cap so the panel grows to fit the form.
        SIZE_CLASSES = {
          sm: "w-full sm:w-[400px]",
          md: "w-full sm:w-[480px]",
          lg: "w-full sm:w-[640px]",
          xl: "w-full sm:w-[800px]",
          auto: "w-full sm:w-auto sm:max-w-[90vw] sm:min-w-[480px]",
          full: "w-full sm:w-[95vw]"
        }.freeze

        protected

        # Animation is driven by `data-open`, toggled by the remote-modal
        # controller on the frame after showModal(). Mirrors the filter
        # slideover's pattern — see Centered for the same rationale.
        def base_dialog_classes
          "fixed top-0 right-0 bottom-0 left-auto m-0 h-screen max-w-full max-h-screen " \
            "bg-[var(--pu-surface)] border-l border-[var(--pu-border)] " \
            "backdrop:bg-transparent data-[open]:backdrop:bg-black/60 " \
            "data-[open]:backdrop:backdrop-blur-sm " \
            "backdrop:transition-[background-color] backdrop:duration-300 backdrop:ease-out " \
            "rounded-none p-0 " \
            "open:flex flex-col " \
            "translate-x-full data-[open]:translate-x-0 " \
            "transition-transform duration-300 ease-out"
        end
      end
    end
  end
end
