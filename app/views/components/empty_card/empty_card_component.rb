module Plutonium::UI
  class EmptyCardComponent < Plutonium::UI::Base
    option :message
  end
end

Plutonium::ComponentRegistry.register :empty_card, to: Plutonium::UI::EmptyCardComponent
