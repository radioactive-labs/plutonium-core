module Plutonium
  module Core
    module Controllers
      module Bootable
        extend ActiveSupport::Concern

        included do
          class_attribute :current_package, instance_writer: false, instance_predicate: false
          class_attribute :current_engine, instance_writer: false, instance_predicate: false

          helper_method :current_engine, :current_package
        end

        class_methods do
          def boot(package)
            self.current_package = package
            self.current_engine = "#{package}::Engine".constantize

            prepend_view_path current_engine.paths["app/views"].first
          end
        end
      end
    end
  end
end
