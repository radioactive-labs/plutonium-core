module Plutonium
  module Core
    module Controllers
      module Bootable
        extend ActiveSupport::Concern

        included do
          class_attribute :package
          class_attribute :resource_class, instance_writer: false, instance_predicate: false

          helper_method :resource_class
        end

        class_methods do
          def current_engine
            "#{package}::Engine".constantize
          end

          private

          def boot(package)
            self.package = package

            prepend_view_path current_engine.paths["app/views"].first
          end

          def controller_for(resource_class)
            self.resource_class = resource_class
          end
        end

        private

        def current_engine
          @current_engine ||= self.class.current_engine
        end

        def current_package
          self.class.package
        end
      end
    end
  end
end
