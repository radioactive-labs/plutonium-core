module PlutoniumUi
  class SidebarComponent < PlutoniumUi::Base
    private

    def base_attributes
      # base attributes go here
      {
        id: "sidebar-navigation",
        controller: "",
        aria: {label: "Sidebar Navigation"},
        data: {turbo_permanent: true},
        class: "fixed top-0 left-0 z-40 w-64 h-screen pt-14 transition-transform -translate-x-full lg:translate-x-0",
        sidebar_container_class: "overflow-y-auto py-5 px-3 h-full bg-white border-r border-gray-200 dark:bg-gray-800 dark:border-gray-700"
      }
    end

    def sidebar_container_class
      raw_attributes_hash[:sidebar_container_class]
    end
  end
end

Plutonium::ComponentRegistry.register :sidebar, to: PlutoniumUi::SidebarComponent
