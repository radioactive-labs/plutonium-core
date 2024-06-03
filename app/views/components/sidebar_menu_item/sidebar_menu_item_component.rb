module Plutonium::Ui
  class SidebarMenuItemComponent < Plutonium::Ui::Base
    renders_many :sub_items, "::Plutonium::Ui::SidebarMenuItemComponent"

    option :name
    option :url, default: -> { "" }
    option :options, default: -> { {} }

    private

    def base_attributes
      # base attributes go here
      {
        id: "sidebar-menu-item-#{name.parameterize}",
        classname: "sidebar-menu-item",
        controller: ["sidebar-menu-item", sub_items.any? ? "resource-drop-down" : nil],
        link_button_class: "group flex items-center rounded-lg p-2 text-base font-medium text-gray-900 hover:bg-gray-100 dark:text-white dark:hover:bg-gray-700",
        link_label_class: "flex-1 ml-3 text-left whitespace-nowrap",
        sub_link_button_class: "flex items-center p-2 pl-11 w-full text-base font-medium text-gray-900 rounded-lg transition duration-75 group hover:bg-gray-100 dark:text-white dark:hover:bg-gray-700"
      }
    end

    def filtered_attributes
      %i[link_button_class link_label_class sub_link_button_class]
    end

    def link_button_class
      raw_attributes_hash[:link_button_class]
    end

    def link_label_class
      raw_attributes_hash[:link_label_class]
    end

    def sub_link_button_class
      raw_attributes_hash[:sub_link_button_class]
    end
  end
end

Plutonium::ComponentRegistry.register :sidebar_menu_item, to: Plutonium::Ui::SidebarMenuItemComponent
