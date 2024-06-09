module Plutonium
  module Helpers
    module AssetsHelper
      def resource_stylesheet_tag
        url = if Plutonium.development?
          filename = JSON.parse(File.read(Plutonium.root.join("src", "build", "css.manifest")))["plutonium.css"]
          "/build/#{filename}"
        else
          resource_stylesheet_asset
        end
        stylesheet_link_tag url, "data-turbo-track": "reload"
      end

      def resource_script_tag
        url = if Plutonium.development?
          filename = JSON.parse(File.read(Plutonium.root.join("src", "build", "js.manifest")))["plutonium.js"]
          "/build/#{filename}"
        else
          resource_script_asset
        end
        javascript_include_tag url, "data-turbo-track": "reload", type: "module"
      end

      def resource_favicon_tag
        favicon_link_tag resource_favicon_asset
      end

      def resource_logo_tag(classname:)
        image_tag resource_logo_asset, class: classname
      end

      def resource_logo_asset = Rails.application.config.plutonium.assets.logo

      def resource_stylesheet_asset = Rails.application.config.plutonium.assets.stylesheet

      def resource_script_asset = Rails.application.config.plutonium.assets.script

      def resource_favicon_asset = Rails.application.config.plutonium.assets.favicon
    end
  end
end
