module Plutonium::Ui
  class NavGridMenuComponent < Plutonium::Ui::Base
    renders_many :items, "Plutonium::Ui::NavGridMenuItemComponent"

    option :label

    private

    def base_attributes
      # base attributes go here
      {
        classname: "nav-grid-menu",
        controller: "nav-grid-menu resource-drop-down"
      }
    end

    def render?
      items.any?
    end
  end
end

Plutonium::ComponentRegistry.register :nav_grid_menu, to: Plutonium::Ui::NavGridMenuComponent
