module PlutoniumUi
  class PanelComponent < PlutoniumUi::Base
    renders_many :actions

    option :title, optional: true

    private

    def base_attributes
      {
        classname: "p-4"
      }
    end
  end
end

Plutonium::ComponentRegistry.register :panel, to: PlutoniumUi::PanelComponent
