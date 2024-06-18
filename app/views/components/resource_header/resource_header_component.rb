module PlutoniumUi
  class ResourceHeaderComponent < PlutoniumUi::Base
    renders_one :brand_logo
    renders_many :actions

    option :brand_name, optional: true
    option :default_brand_logo, default: -> { true }
    option :sidebar_toggle, default: -> {}

    private

    def base_attributes
      # base attributes go here
      {
        classname: "resource-header bg-white border-b border-gray-200 px-4 py-2.5 dark:bg-gray-800 dark:border-gray-700 fixed left-0 right-0 top-0 z-50",
        controller: "resource-header"
      }
    end

    def before_render
      return if brand_logo.present? || !default_brand_logo

      with_brand_logo do
        resource_logo_tag classname: "mr-3 h-10"
      end
    end
  end
end

Plutonium::ComponentRegistry.register :resource_header, to: PlutoniumUi::ResourceHeaderComponent
