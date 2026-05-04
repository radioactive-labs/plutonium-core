module Plutonium
  module Rodauth
    module ControllerMethods
      extend ActiveSupport::Concern

      included do
        helper Plutonium::Helpers::ApplicationHelper
        helper Plutonium::Helpers::AssetsHelper

        layout "rodauth"
        append_view_path File.expand_path("app/views", Plutonium.root)
        helper_method :root_path
      end

      private

      def root_path
        if main_app.routes.url_helpers.respond_to?(:root_path)
          main_app.root_path
        else
          rodauth.login_redirect
        end
      end
    end
  end
end
