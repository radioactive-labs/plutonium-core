module Plutonium::Ui
  class SidebarMenuComponent < Plutonium::Ui::Base
    option :separated, optional: true

    private

    def menu_class
      "space-y-2 #{separated ? "pt-5 mt-5 border-t border-gray-200 dark:border-gray-700" : nil}"
    end
  end
end

Plutonium::ComponentRegistry.register :sidebar_menu, to: Plutonium::Ui::SidebarMenuComponent
