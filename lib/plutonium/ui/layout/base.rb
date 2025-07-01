module Plutonium
  module UI
    module Layout
      class Base < Plutonium::UI::Component::Base
        include Plutonium::Helpers::AssetsHelper
        include Phlex::Rails::Helpers::CSPMetaTag
        include Phlex::Rails::Helpers::CSRFMetaTags
        include Phlex::Rails::Helpers::FaviconLinkTag
        include Phlex::Rails::Helpers::StylesheetLinkTag
        include Phlex::Rails::Helpers::JavascriptIncludeTag
        include Phlex::Rails::Helpers::TurboFrameTag

        def view_template(&)
          doctype
          html(**html_attributes) {
            render_head
            render_body(&)
          }
        end

        private

        def lang = nil

        def page_title = helpers.controller.instance_variable_get(:@page_title)

        def html_attributes = {lang:, data_controller: "color-mode"}

        def body_attributes = {class: "antialiased min-h-screen bg-gray-50 dark:bg-gray-900"}

        def main_attributes = {class: "p-4 min-h-screen"}

        def render_head
          head {
            render_title
            render_metatags
            render_assets
          }
        end

        def render_body(&)
          body(**body_attributes) {
            render_before_main
            render_main(&)
            render_after_main
            render_body_scripts
          }
        end

        def render_before_main
        end

        def render_main(&)
          main(**main_attributes) {
            render_flash
            render_before_content
            render_content(&)
            render_after_content
          }
        end

        def render_flash
          render partial("flash")
        end

        def render_before_content
        end

        def render_after_main
          turbo_frame_tag("remote_modal")
        end

        def render_content(&)
          yield if block_given?
        end

        def render_after_content
        end

        def render_title
          title { page_title } if page_title
        end

        def render_metatags
          render_base_metatags
          render_security_metatags
          render_turbo_metatags
        end

        def render_base_metatags
          meta(charset: "utf-8")
          meta(name: "viewport", content: "width=device-width,initial-scale=1")
        end

        def render_security_metatags
          csrf_meta_tags
          csp_meta_tag
        end

        def render_turbo_metatags
          meta(name: "turbo-cache-control", content: "no-cache")
          meta(name: "turbo-refresh-method", content: "morph")
          meta(name: "turbo-refresh-scroll", content: "preserve")
        end

        def render_fonts
          link(rel: "preconnect", href: "https://fonts.googleapis.com")
          link(rel: "preconnect", href: "https://fonts.gstatic.com", crossorigin: true)
          link(href: "https://fonts.googleapis.com/css2?family=Lato:ital,wght@0,100;0,300;0,400;0,700;0,900;1,100;1,300;1,400;1,700;1,900&display=swap", rel: "stylesheet")
        end

        def render_favicon
          favicon_link_tag(Plutonium.configuration.assets.favicon) if Plutonium.configuration.assets.favicon
        end

        def render_assets
          render_favicon
          render_fonts
          render_styles
          render_scripts
        end

        def render_styles
          render_external_styles

          url = resource_asset_url_for(:css, resource_stylesheet_asset)
          stylesheet_link_tag(url, "data-turbo-track": "reload")
        end

        def render_external_styles
          link(
            rel: "stylesheet",
            href: "https://cdn.jsdelivr.net/npm/flatpickr@4.6.13/dist/flatpickr.min.css",
            integrity: "sha384-RkASv+6KfBMW9eknReJIJ6b3UnjKOKC5bOUaNgIY778NFbQ8MtWq9Lr/khUgqtTt",
            crossorigin: "anonymous"
          )
          link(
            rel: "stylesheet",
            href: "https://cdn.jsdelivr.net/npm/intl-tel-input@24.8.1/build/css/intlTelInput.min.css",
            integrity: "sha384-oE0RVGDyNw9goP8V3wYWC9+3GYojVc/LhhKmLT9J5k+L+oGHPa1gRF3FomvOCOFs",
            crossorigin: "anonymous"
          )
          link(
            rel: "stylesheet",
            href: "https://cdn.jsdelivr.net/npm/@uppy/core@4.3.1/dist/style.min.css",
            integrity:
              "sha384-duO7yazRrDcRaU8fsOcR3nRyiE7zYi14hncnPBJwqwtTNIaOSMoedatlLJgOcuWC",
            crossorigin: "anonymous"
          )
          link(
            rel: "stylesheet",
            href:
              "https://cdn.jsdelivr.net/npm/@uppy/dashboard@4.1.3/dist/style.min.css",
            integrity:
              "sha384-zhtN/7sNIm7zP9ccJ0oz4Bhoe1iy2gZM9y37fMgGqWDSY5AIeGoPzAfnqbW6bYII",
            crossorigin: "anonymous"
          )
          link(
            rel: "stylesheet",
            href:
              "https://cdn.jsdelivr.net/npm/@uppy/image-editor@3.2.1/dist/style.min.css",
            integrity:
              "sha384-Wk0+fOnKCX5R8Clls7c6jbYFLDZe43o6j9HFR9AUmOrc+TQZH6B4DFnXhvwhNPyG",
            crossorigin: "anonymous"
          )
          link(
            rel: "stylesheet",
            href:
              "https://cdn.jsdelivr.net/npm/easymde@2.18.0/dist/easymde.min.css",
            integrity:
              "uqD/OYCNfagd1EgXMgl5QedTD5K+B3e9b8GYo/41t7+Serf7CBxvl+tU1gHd+qd1",
            crossorigin: "anonymous"
          )
        end

        def render_scripts
          render_external_scripts

          url = resource_asset_url_for(:js, resource_script_asset)
          javascript_include_tag(url, "data-turbo-track": "reload", type: "module")
        end

        def render_external_scripts
          script(
            src: "https://cdn.jsdelivr.net/npm/easymde@2.18.0/dist/easymde.min.js",
            integrity: "sha384-KtB38COewxfrhJxoN2d+olxJAeT08LF8cVZ6DQ8Poqu89zIptqO6zAXoIxpGNWYE",
            crossorigin: "anonymous"
          )
          script(
            src: "https://cdn.jsdelivr.net/npm/slim-select@2.10.0/dist/slimselect.umd.min.js",
            integrity: "sha384-WKsmo+vSs0gqrT+es6wFEojVFn4P0kNaHpHTIkn84iHY8T4rF2V2McZeSbLPLlHy",
            crossorigin: "anonymous"
          )
          script(
            src: "https://cdn.jsdelivr.net/npm/flatpickr@4.6.13/dist/flatpickr.min.js",
            integrity: "sha384-5JqMv4L/Xa0hfvtF06qboNdhvuYXUku9ZrhZh3bSk8VXF0A/RuSLHpLsSV9Zqhl6",
            crossorigin: "anonymous"
          )
          script(
            src: "https://cdn.jsdelivr.net/npm/intl-tel-input@24.8.1/build/js/intlTelInput.min.js",
            integrity: "sha384-oCoRbvnGGnM56vTrLX0f7cgRy2aqLchemkQhvfBT7J+b6km6CSuWz/89IpPnTq9j",
            crossorigin: "anonymous"
          )
        end

        def render_body_scripts
        end
      end
    end
  end
end
