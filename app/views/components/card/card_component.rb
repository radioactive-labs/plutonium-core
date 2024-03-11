module Plutonium::UI
  class CardComponent < Plutonium::UI::Base
  end
end

Plutonium::ComponentRegistry.register :card, to: Plutonium::UI::CardComponent
