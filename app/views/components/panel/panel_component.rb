module Plutonium::Ui
  class PanelComponent < Plutonium::Ui::Base
    option :title, optional: true

    def classname
      "p-4 #{super}"
    end
  end
end

Plutonium::ComponentRegistry.register :panel, to: Plutonium::Ui::PanelComponent
