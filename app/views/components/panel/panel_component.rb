module Plutonium::UI
  class PanelComponent < Plutonium::UI::Base
  end
end

Plutonium::ComponentRegistry.register :panel, to: Plutonium::UI::PanelComponent
