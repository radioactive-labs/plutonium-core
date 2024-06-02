module Plutonium::Ui
  class HasManyPanelComponent < Plutonium::Ui::Base
    option :title
    option :src
  end
end

Plutonium::ComponentRegistry.register :has_many_panel, to: Plutonium::Ui::HasManyPanelComponent
