module Plutonium
  module UI
    module Layout
      class ResourceLayout < Base
        private

        def main_attributes
          classes = case Plutonium.configuration.shell
          when :modern
            "pt-16 pb-6 px-6 lg:pl-20"
          else
            "pt-20 lg:ml-64"
          end

          mix(super, {class: classes})
        end

        def page_title
          make_page_title(
            controller.instance_variable_get(:@page_title)
          )
        end

        def render_before_main
          super

          render partial("resource_header")
          render partial("resource_sidebar")
        end
      end
    end
  end
end
