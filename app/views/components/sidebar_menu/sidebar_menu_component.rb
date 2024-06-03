module Plutonium::Ui
  class SidebarMenuComponent < Plutonium::Ui::Base
    renders_many :items, "::Plutonium::Ui::SidebarMenuItemComponent"

    private

    def base_attributes
      # base attributes go here
      {
        classname: "sidebar-menu space-y-2",
        controller: "sidebar-menu"
      }
    end
  end
end

Plutonium::ComponentRegistry.register :sidebar_menu, to: Plutonium::Ui::SidebarMenuComponent
