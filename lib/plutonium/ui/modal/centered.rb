# frozen_string_literal: true

module Plutonium
  module UI
    module Modal
      class Centered < Plutonium::UI::Modal::Base
        # Width tokens for each VALID_SIZES key. `:md` reproduces the
        # historical default (`w-full max-w-xl`); `:auto` drops `w-full`
        # so the dialog hugs its content, with a floor that keeps tiny
        # confirm dialogs from collapsing and a cap to stay on-screen.
        SIZE_CLASSES = {
          sm: "w-full max-w-md",
          md: "w-full max-w-xl",
          lg: "w-full max-w-2xl",
          xl: "w-full max-w-4xl",
          auto: "w-fit max-w-[90vw] min-w-[400px]",
          full: "w-full max-w-[95vw]"
        }.freeze

        protected

        # Transparent full-viewport flex container that centers the panel.
        # Deliberately transform-free (see Base#dialog_classes): the panel,
        # not the dialog, carries the scale animation, so fixed UI opened
        # from inside the modal isn't trapped in a transformed box. The
        # backdrop dim+blur is static (not transitioned) so the GPU
        # rasterises the blur once instead of every frame.
        def base_dialog_classes
          "group fixed inset-0 m-0 w-full h-full max-w-none max-h-none " \
            "bg-transparent border-0 p-0 " \
            "open:flex items-center justify-center " \
            "backdrop:bg-black/60 backdrop:backdrop-blur-sm"
        end

        # Surface (`.pu-dialog`) + the open/close opacity+scale animation,
        # driven by the dialog's `[data-open]` via `group-data-[open]:`
        # (set on the frame after showModal() by remote_modal_controller;
        # avoids the @starting-style spec dance). The transition must name
        # `scale` (not `transform`): Tailwind v4's `scale-*` sets the
        # discrete `scale` CSS property, so `transition-[...,transform]`
        # would leave the scale pop un-animated.
        def base_panel_classes
          "pu-dialog flex flex-col min-h-0 max-h-[80vh] overflow-hidden " \
            "opacity-0 scale-95 group-data-[open]:opacity-100 group-data-[open]:scale-100 " \
            "transition-[opacity,scale] duration-200 ease-out"
        end
      end
    end
  end
end
