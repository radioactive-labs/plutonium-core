module Plutonium::UI
  class PanelComponent < Plutonium::UI::Base
    option :title, optional: true

    def classname
      "p-4 #{super}"
    end
  end
end

Plutonium::ComponentRegistry.register :panel, to: Plutonium::UI::PanelComponent
