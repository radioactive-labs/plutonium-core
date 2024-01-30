module Plutonium
  module Core
    module Fields
      module Renderers
        class BasicRenderer < Plutonium::Core::Fields::Renderer
          attr_reader :helper

          def initialize(*args, helper: nil, **options)
            super(*args, **options)

            @helper = helper
          end

          def render(view_context, record)
            view_context.display_field value: record.send(name), helper:, **options
          end
        end
      end
    end
  end
end
