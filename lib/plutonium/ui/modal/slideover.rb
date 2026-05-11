# frozen_string_literal: true

module Plutonium
  module UI
    module Modal
      class Slideover < Plutonium::UI::Modal::Base
        protected

        def dialog_classes
          "fixed top-0 right-0 bottom-0 left-auto m-0 h-screen w-full sm:w-[480px] max-w-full max-h-screen " \
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
