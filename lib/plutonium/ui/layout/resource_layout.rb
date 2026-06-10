module Plutonium
  module UI
    module Layout
      class ResourceLayout < Base
        private

        # Sets pu-rail-pinned immediately on initial page load so the rail
        # renders in its pinned state from the first frame. Turbo navigations
        # are handled by the turbo:before-render listener in Base.
        def render_pre_paint_scripts
          super
          script do
            raw(safe(<<~JS))
              (function () {
                try {
                  if (localStorage.getItem("pu_rail_pinned") !== "false") {
                    document.documentElement.classList.add("pu-rail-pinned");
                  }
                } catch (e) {}
              })();
            JS
          end
        end

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
