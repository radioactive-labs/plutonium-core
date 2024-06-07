module PlutoniumUi
  class ResourceHeaderComponent < PlutoniumUi::Base
    renders_one :brand_logo
    renders_many :actions

    option :brand_name

    private

    def base_attributes
      # base attributes go here
      {
        classname: "resource-header bg-white border-b border-gray-200 px-4 py-2.5 dark:bg-gray-800 dark:border-gray-700 fixed left-0 right-0 top-0 z-50",
        controller: "resource-header"
      }
    end
  end
end

Plutonium::ComponentRegistry.register :resource_header, to: PlutoniumUi::ResourceHeaderComponent
