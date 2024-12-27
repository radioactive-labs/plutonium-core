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
        rodauth.login_redirect
      end
    end
  end
end
