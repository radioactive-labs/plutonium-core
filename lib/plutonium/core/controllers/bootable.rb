module Plutonium
  module Core
    module Controllers
      module Bootable
        extend ActiveSupport::Concern
        include Plutonium::EngineValidator

        included do
          helper_method :current_package, :current_engine
        end

        def current_package
          self.class.current_package
        end

        def current_engine
          self.class.current_engine
        end

        class_methods do
          include Plutonium::Lib::SmartCache

          def inherited(subclass)
            super

            subclass.boot
          end

          def boot(package = nil)
            if package.present?
              ActiveSupport::Deprecation.new("0.15.0", "Plutonium").warn(
                "Calling boot with an argument is deprecated and no longer has an effect. It will be removed in the next version.",
                caller_locations(1)
              )
            end

            if current_engine != Rails.application.class
              prepend_view_path current_engine.paths["app/views"].first
            end
          end

          def current_package
            (current_engine == Rails.application.class) ? nil : current_engine.module_parent
          end
          memoize_unless_reloading :current_package

          def current_engine
            potential_package = module_parents[-2]
            engine = potential_package.nil? ? Rails.application.class : ("#{potential_package}::Engine".safe_constantize || Rails.application.class)
            validate_engine! engine
            engine
          end
          memoize_unless_reloading :current_engine
        end
      end
    end
  end
end
