module Plutonium
  module Core
    module Fields
      module Renderers
        class AttachmentRenderer < AssociationRenderer
          def render
            attachment_preview value, **options
          end

          private

          def renderer_options
            {
              caption: true
            }
          end
        end
      end
    end
  end
end
