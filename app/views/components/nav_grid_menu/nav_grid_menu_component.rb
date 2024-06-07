module PlutoniumUi
  class NavGridMenuComponent < PlutoniumUi::Base
    renders_many :items, "PlutoniumUi::NavGridMenuItemComponent"

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

Plutonium::ComponentRegistry.register :nav_grid_menu, to: PlutoniumUi::NavGridMenuComponent
