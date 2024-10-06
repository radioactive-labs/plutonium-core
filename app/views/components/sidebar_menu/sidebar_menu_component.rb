module PlutoniumUi
  class SidebarMenuComponent < PlutoniumUi::Base
    renders_many :items, "::PlutoniumUi::SidebarMenuItemComponent"

    private

    def base_attributes
      # base attributes go here
      {
        classname: "sidebar-menu space-y-2 pb-6 mb-6",
        controller: "sidebar-menu"
      }
    end
  end
end

Plutonium::ComponentRegistry.register :sidebar_menu, to: PlutoniumUi::SidebarMenuComponent
