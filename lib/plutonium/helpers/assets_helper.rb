# frozen_string_literal: true

module Plutonium
  module Helpers
    # Helper module for managing asset-related functionality
    module AssetsHelper
      # Generate a stylesheet tag for the resource
      #
      # @return [ActiveSupport::SafeBuffer] HTML stylesheet link tag
      def resource_stylesheet_tag
        url = resource_asset_url_for(:css, resource_stylesheet_asset)
        stylesheet_link_tag(url, "data-turbo-track": "reload")
      end

      # Generate a script tag for the resource
      #
      # @return [ActiveSupport::SafeBuffer] HTML script tag
      def resource_script_tag
        url = resource_asset_url_for(:js, resource_script_asset)
        javascript_include_tag(url, "data-turbo-track": "reload", type: "module")
      end

      # Generate a favicon link tag
      #
      # @return [ActiveSupport::SafeBuffer] HTML favicon link tag
      def resource_favicon_tag
        favicon_link_tag(resource_favicon_asset)
      end

      # Generate an image tag for the logo
      #
      # @param classname [String] CSS class name for the image tag
      # @return [ActiveSupport::SafeBuffer] HTML image tag
      def resource_logo_tag(classname:)
        render Plutonium::UI::Display::Components::Logo.new(classname:)
      end

      # Get the stylesheet asset path
      #
      # @return [String] path to the stylesheet asset
      def resource_stylesheet_asset
        Plutonium.configuration.assets.stylesheet
      end

      # Get the script asset path
      #
      # @return [String] path to the script asset
      def resource_script_asset
        Plutonium.configuration.assets.script
      end

      # Get the favicon asset path
      #
      # @return [String] path to the favicon asset
      def resource_favicon_asset
        Plutonium.configuration.assets.favicon
      end

      private

      # Generate the appropriate asset URL based on the environment
      #
      # @param type [Symbol] asset type (:css or :js)
      # @param fallback [String] fallback asset path
      # @return [String] asset URL
      def resource_asset_url_for(type, fallback)
        if Plutonium.configuration.development?
          resource_development_asset_url(type)
        else
          fallback
        end
      end

      # Generate the asset URL for development environment
      #
      # @param type [Symbol] asset type (:css or :js)
      # @return [String] asset URL for development
      def resource_development_asset_url(type)
        manifest_file = (type == :css) ? "css.manifest" : "js.manifest"
        asset_key = (type == :css) ? "plutonium.css" : "plutonium.js"

        filename = JSON.parse(File.read(Plutonium.root.join("src", "build", manifest_file)))[asset_key]
        "/build/#{filename}"
      end
    end
  end
end
