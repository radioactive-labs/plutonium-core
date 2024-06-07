module PlutoniumUi
  class NavGridMenuItemComponent < PlutoniumUi::Base
    option :name
    option :icon
    option :url, as: :href

    private

    def base_attributes
      # base attributes go here
      {
        classname: "nav-grid-menu-item block p-4 text-center rounded-lg hover:bg-gray-100 dark:hover:bg-gray-600 group",
        controller: "nav-grid-menu-item",
        href:
      }
    end
  end
end

Plutonium::ComponentRegistry.register :nav_grid_menu_item, to: PlutoniumUi::NavGridMenuItemComponent
