module Plutonium::UI
  class SidebarMenuItemComponent < Plutonium::UI::Base
    option :name
    option :value
    option :indicator, optional: true

    private

    def link_button_class
      "group flex items-center rounded-lg p-2 text-base font-medium text-gray-900 hover:bg-gray-100 dark:text-white dark:hover:bg-gray-700"
    end

    def link_label_class
      "flex-1 ml-3 text-left whitespace-nowrap"
    end

    def sub_link_button_class
      "flex items-center p-2 pl-11 w-full text-base font-medium text-gray-900 rounded-lg transition duration-75 group hover:bg-gray-100 dark:text-white dark:hover:bg-gray-700"
    end
  end
end

Plutonium::ComponentRegistry.register :sidebar_menu_item, to: Plutonium::UI::SidebarMenuItemComponent
