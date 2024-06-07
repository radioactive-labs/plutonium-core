module PlutoniumUi
  class TabBarComponent < PlutoniumUi::Base
    private

    def base_attributes
      {
        controller: "tab-bar"
      }
    end
  end
end

Plutonium::ComponentRegistry.register :tab_bar, to: PlutoniumUi::TabBarComponent
