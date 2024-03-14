module Plutonium::UI
  class PanelComponent < Plutonium::UI::Base
    def classname
      "p-6 #{super}"
    end
  end
end

Plutonium::ComponentRegistry.register :panel, to: Plutonium::UI::PanelComponent
