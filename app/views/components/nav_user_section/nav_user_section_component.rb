module Plutonium::Ui
  class NavUserSectionComponent < Plutonium::Ui::Base
    renders_many :links, "Plutonium::Ui::NavUserLinkComponent"

    private

    def base_attributes
      # base attributes go here
      {
        classname: "nav-user-section text-gray-700 dark:text-gray-300",
        controller: "nav-user-section",
        aria: {labelledby: "user-nav-dropdown-toggle"}
      }
    end
  end
end

Plutonium::ComponentRegistry.register :nav_user_section, to: Plutonium::Ui::NavUserSectionComponent
