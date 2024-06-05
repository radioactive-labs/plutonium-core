module Plutonium::Ui
  class ResourceLayoutComponent < Plutonium::Ui::Base
    renders_one :meta
    renders_one :favicon
    renders_one :fonts
    renders_one :assets
    renders_one :after_head
    renders_one :header
    renders_one :sidebar

    option :page_title
    option :lang
    option :body_classname, default: -> { "antialiased bg-gray-50 dark:bg-gray-900" }
    option :main_classname, default: -> { "p-4 h-auto" }
    option :header_adjustment, default: -> { "pt-20" }
    option :sidebar_adjustment, default: -> { "lg:ml-64" }

    private

    def base_attributes
      # base attributes go here
      {
        classname: "resource-layout",
        controller: "resource-layout color-mode",
        lang:
      }
    end

    def build_main_classname
      classname = Array(main_classname)
      classname += Array(header_adjustment) if header.present?
      classname += Array(sidebar_adjustment) if sidebar.present?

      classname.join " "
    end
  end
end

Plutonium::ComponentRegistry.register :resource_layout, to: Plutonium::Ui::ResourceLayoutComponent
