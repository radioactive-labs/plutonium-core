module Plutonium
  module Core
    module Associations
      module Renderers
        class HasManyRenderer < BasicRenderer
          def render(view_context, record)
            view_context.render_component :has_many_panel,
              title: label,
              src: view_context.resource_url_for(reflection.klass, parent: record),
              **options
          end
        end
      end
    end
  end
end
