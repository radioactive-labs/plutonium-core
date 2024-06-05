module Plutonium::Ui
  class NavUserLinkComponent < Plutonium::Ui::Base
    renders_one :leading
    renders_one :trailing

    option :label
    option :url, as: :href

    private

    def base_attributes
      # base attributes go here
      {
        id: "nav-user-link-#{label.parameterize}",
        classname: "nav-user-link flex justify-between items-center py-2 px-4 text-sm hover:bg-gray-100 dark:hover:bg-gray-600 dark:hover:text-white",
        controller: "nav-user-link",
        href:
      }
    end
  end
end

Plutonium::ComponentRegistry.register :nav_user_link, to: Plutonium::Ui::NavUserLinkComponent
