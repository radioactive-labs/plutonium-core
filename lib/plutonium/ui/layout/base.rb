module Plutonium
  module UI
    module Layout
      class Base < Plutonium::UI::Component::Base
        include Plutonium::Helpers::AssetsHelper
        include Phlex::Rails::Helpers::CSPMetaTag
        include Phlex::Rails::Helpers::CSRFMetaTags
        include Phlex::Rails::Helpers::FaviconLinkTag
        include Phlex::Rails::Helpers::StyleSheetLinkTag
        include Phlex::Rails::Helpers::JavaScriptIncludeTag

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

        def html_attributes = {lang:, data_controller: "resource-layout color-mode"}

        def body_attributes = {class: "antialiased min-h-screen bg-gray-50 dark:bg-gray-900"}

        def main_attributes = {class: "p-4 min-h-screen"}

        def render_head
          head {
            render_title
            render_metatags
            render_security_metatags
            render_turbo_metatags
            render_font_tags
            render_favicon_tag
            render_assets_tags

            # plain assets
            # plain head
            # <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/quill/1.3.7/quill.snow.min.css" integrity="sha512-/FHUK/LsH78K9XTqsR9hbzr21J8B8RwHR/r8Jv9fzry6NVAOVIGFKQCNINsbhK7a1xubVu2r5QZcz2T9cKpubw==" crossorigin="anonymous" referrerpolicy="no-referrer" /> '
            # <script src="https://cdnjs.cloudflare.com/ajax/libs/quill/1.3.7/quill.min.js" integrity="sha512-P2W2rr8ikUPfa31PLBo5bcBQrsa+TNj8jiKadtaIrHQGMo6hQM6RdPjQYxlNguwHz8AwSQ28VkBK6kHBLgd/8g==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
            # <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/slim-select/2.6.0/slimselect.min.css" integrity="sha512-GvqWM4KWH8mbgWIyvwdH8HgjUbyZTXrCq0sjGij9fDNiXz3vJoy3jCcAaWNekH2rJe4hXVWCJKN+bEW8V7AAEQ==" crossorigin="anonymous" referrerpolicy="no-referrer" />
            # <script src="https://cdnjs.cloudflare.com/ajax/libs/slim-select/2.6.0/slimselect.min.js" integrity="sha512-0E8oaoA2v32h26IycsmRDShtQ8kMgD91zWVBxdIvUCjU3xBw81PV61QBsBqNQpWkp/zYJZip8Ag3ifmzz1wCKQ==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
          }
        end

        def render_body(&)
          body(**body_attributes) {
            render_before_main
            render_main(&)
            render_after_main
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
          render "flash"
        end

        def render_before_content
        end

        def render_after_main
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

        def render_font_tags
          link(rel: "preconnect", href: "https://fonts.googleapis.com")
          link(rel: "preconnect", href: "https://fonts.gstatic.com", crossorigin: true)
          link(href: "https://fonts.googleapis.com/css2?family=Lato:ital,wght@0,100;0,300;0,400;0,700;0,900;1,100;1,300;1,400;1,700;1,900&display=swap", rel: "stylesheet")
        end

        def render_favicon_tag
          favicon_link_tag(Plutonium.configuration.assets.favicon) if Plutonium.configuration.assets.favicon
        end

        def render_assets_tags
          render_asset_style_tags
          render_asset_scripts_tags
        end

        def render_asset_style_tags
          url = resource_asset_url_for(:css, resource_stylesheet_asset)
          stylesheet_link_tag(url, "data-turbo-track": "reload")
        end

        def render_asset_scripts_tags
          url = resource_asset_url_for(:js, resource_script_asset)
          javascript_include_tag(url, "data-turbo-track": "reload", type: "module")
        end
      end
    end
  end
end
