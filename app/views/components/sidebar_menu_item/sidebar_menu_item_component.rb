module PlutoniumUi
  class SidebarMenuItemComponent < PlutoniumUi::Base
    renders_many :sub_items, "::PlutoniumUi::SidebarMenuItemComponent"

    option :name
    option :url, default: -> { "" }
    option :options, default: -> { {} }
    option :icon, optional: true

    private

    def base_attributes
      # base attributes go here
      {
        id: "sidebar-menu-item-#{name.parameterize}",
        classname: "sidebar-menu-item",
        controller: ["sidebar-menu-item", sub_items.any? ? "resource-collapse" : nil],
        link_button_class: "flex items-center p-2 w-full text-base font-normal text-gray-900 rounded-lg transition duration-75 group hover:bg-gray-100 dark:text-white dark:hover:bg-gray-700",
        link_link_class: "flex items-center p-2 text-base font-normal text-gray-900 rounded-lg dark:text-white hover:bg-gray-100 dark:hover:bg-gray-700 group",
        link_label_class: "flex-1 ml-3 text-left whitespace-nowrap",
        sub_link_button_class: "flex items-center p-2 pl-11 w-full text-base font-normal text-gray-900 rounded-lg transition duration-75 group hover:bg-gray-100 dark:text-white dark:hover:bg-gray-700",
        icon_class: "text-gray-400 transition duration-75 dark:text-gray-400 group-hover:text-gray-900 dark:group-hover:text-white"
      }
    end

    def filtered_attributes
      %i[link_button_class link_label_class sub_link_button_class link_link_class icon_class]
    end

    def link_button_class
      raw_attributes_hash[:link_button_class]
    end

    def link_link_class
      raw_attributes_hash[:link_link_class]
    end

    def link_label_class
      raw_attributes_hash[:link_label_class]
    end

    def sub_link_button_class
      raw_attributes_hash[:sub_link_button_class]
    end

    def icon_class
      raw_attributes_hash[:icon_class]
    end
  end
end

Plutonium::ComponentRegistry.register :sidebar_menu_item, to: PlutoniumUi::SidebarMenuItemComponent
