module Plutonium
  module Rodauth
    module ControllerMethods
      extend ActiveSupport::Concern

      included do
        helper Plutonium::Helpers::ApplicationHelper
        helper Plutonium::Helpers::ComponentHelper
        helper Plutonium::Helpers::AssetsHelper
        helper Plutonium::Helpers::FormHelper

        layout "rodauth"
        append_view_path File.expand_path("app/views", Plutonium.root)
        helper_method :root_path
      end

      private

      def root_path
        "/"
      end
    end
  end
end
