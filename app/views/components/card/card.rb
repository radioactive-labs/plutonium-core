module Plutonium::UI
  class Card < Plutonium::UI::Base
  end
end

Plutonium::ComponentRegistry.register :card, to: Plutonium::UI::Card
