module Plutonium
  module Core
    module Fields
      module Renderers
        class BasicRenderer < Base
          def render
            display_field value:, **options
          end
        end
      end
    end
  end
end
