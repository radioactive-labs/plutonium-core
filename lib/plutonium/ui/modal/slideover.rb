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

        def base_dialog_classes
          "fixed top-0 right-0 bottom-0 left-auto m-0 h-screen max-w-full max-h-screen " \
            "bg-[var(--pu-surface)] border-l border-[var(--pu-border)] " \
            "backdrop:bg-black/60 backdrop:backdrop-blur-sm " \
            "rounded-none p-0 " \
            "hidden open:flex flex-col " \
            "translate-x-full open:translate-x-0 " \
            "transition-[transform,display,overlay] duration-300 ease-out " \
            "[transition-behavior:allow-discrete] " \
            "starting:open:translate-x-full " \
            "backdrop:transition-[display,overlay,background-color] backdrop:duration-300 " \
            "backdrop:[transition-behavior:allow-discrete] " \
            "starting:open:backdrop:bg-transparent"
        end
      end
    end
  end
end
