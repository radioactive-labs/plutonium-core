module Plutonium
  module Core
    module FeatureController
      extend ActiveSupport::Concern

      included do
        class_attribute :package
      end

      class_methods do
        def boot(package)
          self.package = package

          prepend_view_path current_engine.paths["app/views"].first
        end

        def current_engine
          "#{package}::Engine".constantize
        end
      end

      def current_engine
        self.class.current_engine
      end

      def current_package
        self.class.package
      end
    end
  end
end
