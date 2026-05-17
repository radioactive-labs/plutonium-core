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

        # Animation is driven by `data-open`, toggled by the remote-modal
        # controller on the frame after showModal(). Avoids the
        # @starting-style / allow-discrete approach, which is unreliable
        # across browsers; mirrors the filter slideover's pattern.
        def base_dialog_classes
          "rounded-[var(--pu-radius-lg)] " \
            "bg-[var(--pu-surface)] border border-[var(--pu-border)] " \
            "backdrop:bg-transparent data-[open]:backdrop:bg-black/60 " \
            "data-[open]:backdrop:backdrop-blur-sm " \
            "backdrop:transition-[background-color] backdrop:duration-200 backdrop:ease-out " \
            "top-1/2 -translate-y-1/2 left-1/2 -translate-x-1/2 " \
            "max-h-[80vh] " \
            "open:flex flex-col p-0 " \
            "opacity-0 scale-95 data-[open]:opacity-100 data-[open]:scale-100 " \
            "transition-[opacity,transform] duration-200 ease-out"
        end
      end
    end
  end
end
