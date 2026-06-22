module Plutonium
  module UI
    module Layout
      class ResourceLayout < Base
        private

        # Whether the modern icon rail is active for this request. Delegates to
        # the controller's resolution (shell default + per-controller `rail`).
        def rail? = controller.rail?

        def shell = controller.shell

        # Override Base's seam so all pre-paint shell logic uses the resolved
        # (controller/engine/global) shell rather than only the global config.
        def pre_paint_shell = shell

        # Sets pu-rail-pinned immediately on initial page load so the rail
        # renders in its pinned state from the first frame. Turbo navigations
        # are handled by the turbo:before-render listener in Base. Skipped
        # entirely when the layout renders no rail.
        def render_pre_paint_scripts
          super
          return unless rail?

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

        # Adds `pu-no-rail` to <html> (server-side, no FOUC) so decoupled fixed
        # chrome (Topbar, form StickyFooter) can cancel their rail insets.
        # Scoped to the modern family — :classic keeps its own offsets.
        def html_attributes
          attrs = super
          return attrs if shell == :classic

          rail? ? attrs : mix(attrs, {class: "pu-no-rail"})
        end

        def main_attributes
          classes = if shell == :classic
            "pt-20 lg:ml-64"
          else
            rail? ? "pt-16 pb-6 px-6 lg:pl-20" : "pt-16 pb-6 px-6"
          end

          mix(super, {class: classes})
        end

        def page_title
          make_page_title(
            controller.instance_variable_get(:@page_title)
          )
        end

        # The classic shell always renders its sidebar; the modern family
        # renders the icon rail only when the rail is active. Mirrors the
        # classic special-casing in main_attributes/html_attributes, whose
        # offsets are likewise rail-independent for :classic.
        def render_sidebar? = shell == :classic || rail?

        def render_before_main
          super

          render partial("resource_header")
          render partial("resource_sidebar") if render_sidebar?
        end
      end
    end
  end
end
