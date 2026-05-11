# frozen_string_literal: true

module Plutonium
  module UI
    module Modal
      class Centered < Plutonium::UI::Modal::Base
        protected

        def dialog_classes
          "rounded-[var(--pu-radius-lg)] w-full max-w-xl " \
            "bg-[var(--pu-surface)] border border-[var(--pu-border)] " \
            "backdrop:bg-black/60 backdrop:backdrop-blur-sm " \
            "top-1/2 -translate-y-1/2 left-1/2 -translate-x-1/2 " \
            "max-h-[80vh] " \
            "hidden open:flex flex-col p-0 " \
            "opacity-0 open:opacity-100 transition-opacity duration-200 ease-in-out"
        end
      end
    end
  end
end
