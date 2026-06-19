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

        # Transparent full-viewport flex container pinning the panel to the
        # right edge (`justify-end`). Deliberately transform-free (see
        # Base#dialog_classes): the panel, not the dialog, carries the
        # slide, so fixed UI opened from inside isn't trapped in a
        # transformed box. The backdrop dim+blur is static (no [data-open]
        # gating, no transition): a ::backdrop that fades its bg-color while
        # carrying backdrop-filter re-rasterises the blur every frame and
        # stutters the panel slide. Keeping it static lets only the panel
        # animate (transform), composited smoothly.
        def base_dialog_classes
          "group fixed inset-0 m-0 w-full h-full max-w-none max-h-none " \
            "bg-transparent border-0 p-0 " \
            "open:flex justify-end items-stretch " \
            "backdrop:bg-black/60 backdrop:backdrop-blur-sm"
        end

        # Surface + the slide animation, driven by the dialog's `[data-open]`
        # via `group-data-[open]:` (toggled on the frame after showModal()
        # by remote_modal_controller). Mirrors the filter slideover's pattern.
        def base_panel_classes
          "flex flex-col min-h-0 h-full max-h-full overflow-hidden " \
            "bg-[var(--pu-surface)] border-l border-[var(--pu-border)] rounded-none " \
            "translate-x-full group-data-[open]:translate-x-0 " \
            "transition-transform duration-300 ease-out"
        end
      end
    end
  end
end
