module Plutonium
  module Core
    module Controllers
      module Bootable
        extend ActiveSupport::Concern

        included do
          helper_method :current_engine
          helper_method :current_package
        end

        class_methods do
          attr_reader :package, :current_engine

          private

          def boot(package)
            raise "#{self.class} has already booted" if defined?(@package) || defined?(@current_engine)

            @package = package
            @current_engine = "#{package}::Engine".constantize

            prepend_view_path current_engine.paths["app/views"].first
          end
        end

        private

        def current_engine
          self.class.current_engine
        end

        def current_package
          self.class.package
        end
      end
    end
  end
end
