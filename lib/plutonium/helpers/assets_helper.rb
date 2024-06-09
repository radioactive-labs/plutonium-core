module Plutonium
  module Helpers
    module AssetsHelper
      def plutonium_stylesheet_tag
        url = if Plutonium.development?
          file = JSON.parse(File.read(Plutonium.root.join("src", "build", "css.manifest")))["plutonium.css"]
          "/build/#{file}"
        else
          "plutonium"
        end
        stylesheet_link_tag url, "data-turbo-track": "reload"
      end

      def plutonium_script_tag
        url = if Plutonium.development?
          file = JSON.parse(File.read(Plutonium.root.join("src", "build", "js.manifest")))["plutonium.js"]
          "/build/#{file}"
        else
          "plutonium.min"
        end
        javascript_include_tag url, "data-turbo-track": "reload", type: "module"
      end

      def logo_tag(classname:)
        image_tag logo, class: classname
      end

      def logo
        Plutonium::Config.logo || "plutonium-logo.png"
      end
    end
  end
end
