module Plutonium
  module Core
    module Fields
      module Renderers
        class AssociationRenderer < BasicRenderer
          private

          def renderer_options = {helper: :display_association_value}.freeze
        end
      end
    end
  end
end
