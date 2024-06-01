module Plutonium::Ui
  class PanelComponent < Plutonium::Ui::Base
    option :title, optional: true

    private

    def base_attributes
      {
        classname: "p-4"
      }
    end
  end
end

Plutonium::ComponentRegistry.register :panel, to: Plutonium::Ui::PanelComponent
