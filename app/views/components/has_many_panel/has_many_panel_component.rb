module Plutonium::Ui
  class HasManyPanelComponent < Plutonium::Ui::Base
    option :title
    option :src

    private

    def base_attributes
      {
        controller: %w[has-many-panel frame-navigator]
      }
    end
  end
end

Plutonium::ComponentRegistry.register :has_many_panel, to: Plutonium::Ui::HasManyPanelComponent
