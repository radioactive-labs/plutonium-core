# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # A form's declared `form_layout` section. All chrome lives in the
        # shared {Plutonium::UI::Component::Section} so a form section and a
        # show-page section cannot drift apart; the form contributes only its
        # own grid class (via `columns:`) and the block that renders the
        # fields (the form supplies render_resource_field).
        class Section < Plutonium::UI::Component::Section
          def self.theme_class = Plutonium::UI::Form::Theme
        end
      end
    end
  end
end
