module Plutonium
  module UI
    module Layout
      class RodauthLayout < Base
        include Phlex::Rails::Helpers::LinkTo

        private

        def page_title
          helpers.controller.instance_variable_get(:@page_title)
        end

        def main_attributes = mix(super, {
          class: "flex flex-col items-center justify-center gap-sm px-lg py-xl mx-auto lg:py-0"
        })

        def render_content(&)
          render_logo

          div(class: "w-full bg-surface rounded-sm shadow dark:border md:mt-0 sm:max-w-md xl:p-0 dark:bg-surface-dark dark:border-gray-700") {
            div(class: "p-lg space-y-md md:space-y-lg sm:p-xl", &)
          }

          render_links
        end

        def render_logo
          link_to root_path, class: "flex items-center text-2xl font-semibold text-gray-900 dark:text-white mb-2" do
            helpers.resource_logo_tag classname: "w-24 h-24 mr-sm rounded"
          end
        end

        def render_links
          div(class: "mt-md flex items-center font-medium text-secondary-600 dark:text-secondary-400 hover:underline") {
            render Phlex::TablerIcons::Home2.new
            link_to "Home", root_path, class: "font-medium text-secondary-600 dark:text-secondary-400"
          }
        end
      end
    end
  end
end
