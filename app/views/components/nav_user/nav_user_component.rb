module PlutoniumUi
  class NavUserComponent < PlutoniumUi::Base
    renders_many :sections, "PlutoniumUi::NavUserSectionComponent"

    option :email
    option :name, optional: true
    option :avatar_url, optional: true
    option :logout_url, optional: true

    private

    def base_attributes
      # base attributes go here
      {
        classname: "nav-user",
        controller: "nav-user resource-drop-down"
      }
    end

    def before_render
      return unless logout_url.present?

      content # get block to execute so our link gets added at the very end

      with_section do |section|
        section.with_link url: logout_url, label: "Sign out", data: {turbo: false}, classname: "rounded-b-lg"
      end
    end
  end
end

Plutonium::ComponentRegistry.register :nav_user, to: PlutoniumUi::NavUserComponent
