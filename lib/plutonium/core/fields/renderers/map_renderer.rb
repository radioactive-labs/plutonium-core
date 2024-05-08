module Plutonium
  module Core
    module Fields
      module Renderers
        class MapRenderer < BasicRenderer
          # def initialize(name, reflection:, **user_options)
          #   @reflection = reflection
          #   super(name, **user_options)
          # end

          def render(view_context, record)
            # view_context.display_field value:, **options
            view_context.js_map [{latitude: record.lat, longitude: record.lng}]
          end
        end
      end
    end
  end
end
