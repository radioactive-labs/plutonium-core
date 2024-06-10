module Plutonium
  module Core
    module Associations
      module Renderers
        class HasManyRenderer < Base
          def render
            render_component(
              :has_many_panel,
              title: label,
              src: resource_url_for(reflection.klass, parent: record),
              **options
            )
          end
        end
      end
    end
  end
end
