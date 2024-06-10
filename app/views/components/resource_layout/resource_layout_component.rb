module PlutoniumUi
  class ResourceLayoutComponent < PlutoniumUi::Base
    renders_one :meta
    renders_one :favicon
    renders_one :assets
    renders_one :head
    renders_one :header
    renders_one :sidebar

    option :page_title
    option :lang
    option :body_classname, default: -> { "antialiased min-h-screen w-full bg-gray-50 dark:bg-gray-900" }
    option :main_classname, default: -> { "p-4" }
    option :header_adjustment, default: -> { "pt-20 min-h-screen w-full" }
    option :sidebar_adjustment, default: -> { "lg:ml-64" }
    option :default_turbo_tag, default: -> { true }
    option :default_fonts_tag, default: -> { true }
    option :default_assets_tag, default: -> { true }

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

Plutonium::ComponentRegistry.register :resource_layout, to: PlutoniumUi::ResourceLayoutComponent
