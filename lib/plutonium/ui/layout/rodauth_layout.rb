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
          class: "flex flex-col items-center justify-center gap-2 px-6 py-8 mx-auto lg:py-0"
        })

        def render_content(&)
          render_logo

          div(class: "w-full bg-[var(--pu-surface)] rounded-[var(--pu-radius-lg)] border border-[var(--pu-border)] md:mt-0 sm:max-w-md xl:p-0", style: "box-shadow: var(--pu-shadow-md)") {
            div(class: "p-6 space-y-4 md:space-y-6 sm:p-8", &)
          }

          render_links
        end

        def render_logo
          link_to root_path, class: "flex items-center text-2xl font-semibold text-[var(--pu-text)] mb-2" do
            helpers.resource_logo_tag classname: "w-24 h-24 mr-2 rounded-[var(--pu-radius-md)]"
          end
        end

        def render_links
          div(class: "mt-4 flex items-center font-medium text-secondary-600 dark:text-secondary-400 hover:underline") {
            render Phlex::TablerIcons::Home2.new
            link_to "Home", root_path, class: "font-medium text-secondary-600 dark:text-secondary-400"
          }
        end
      end
    end
  end
end
