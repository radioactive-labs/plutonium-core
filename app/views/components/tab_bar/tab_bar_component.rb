module Plutonium::Ui
  class TabBarComponent < Plutonium::Ui::Base
    private

    def base_attributes
      {
        controller: "tab-bar"
      }
    end
  end
end

Plutonium::ComponentRegistry.register :tab_bar, to: Plutonium::Ui::TabBarComponent
