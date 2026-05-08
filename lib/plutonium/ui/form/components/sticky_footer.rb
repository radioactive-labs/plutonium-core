# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        class StickyFooter < Plutonium::UI::Component::Base
          def view_template(&block)
            div(class: "fixed bottom-0 left-0 right-0 lg:left-14 z-20 " \
                       "h-14 bg-[var(--pu-surface)] border-t border-[var(--pu-border)] " \
                       "px-6 flex items-center justify-end gap-2", &block)
          end
        end
      end
    end
  end
end
