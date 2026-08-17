# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # A show page's declared `display_layout` section. All chrome lives in
        # the shared {Plutonium::UI::Component::Section} so a show-page section
        # and a form section cannot drift apart; the display contributes only
        # its grid class (the themed :section_grid) and the block that renders
        # the fields.
        class Section < Plutonium::UI::Component::Section
          def self.theme_class = Plutonium::UI::Display::Theme
        end
      end
    end
  end
end
