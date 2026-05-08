# frozen_string_literal: true

module Plutonium
  module UI
    module Modal
      class Slideover < Plutonium::UI::Modal::Base
        protected

        def dialog_classes
          "fixed top-0 right-0 bottom-0 m-0 h-screen w-full sm:w-[480px] max-w-full " \
            "bg-[var(--pu-surface)] border-l border-[var(--pu-border)] " \
            "backdrop:bg-black/60 backdrop:backdrop-blur-sm " \
            "rounded-none p-0 " \
            "hidden open:flex flex-col " \
            "translate-x-full open:translate-x-0 " \
            "transition-transform duration-300 ease-out"
        end
      end
    end
  end
end
