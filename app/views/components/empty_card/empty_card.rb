module Plutonium::UI
  class EmptyCard < Plutonium::UI::Base
    option :message
  end
end

Plutonium::ComponentRegistry.register :empty_card, to: Plutonium::UI::EmptyCard
