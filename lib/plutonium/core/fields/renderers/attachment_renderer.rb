module Plutonium
  module Core
    module Fields
      module Renderers
        class AttachmentRenderer < BasicRenderer
          attr_reader :reflection

          def initialize(name, reflection:, **user_options)
            @reflection = reflection
            super(name, **user_options)
          end

          def render(view_context, record)
            view_context.attachment_preview record.send(name), **options
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
