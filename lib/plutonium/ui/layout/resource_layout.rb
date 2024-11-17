module Plutonium
  module UI
    module Layout
      class ResourceLayout < Base
        private

        def main_attributes = mix(super, {
          class: "pt-20 lg:ml-64"
        })

        def page_title
          helpers.make_page_title(
            helpers.controller.instance_variable_get(:@page_title)
          )
        end

        def render_before_main
          super

          render("resource_header", sidebar_toggle: "#{current_engine.dom_id}-drawer")
          render("resource_sidebar")
        end
      end
    end
  end
end