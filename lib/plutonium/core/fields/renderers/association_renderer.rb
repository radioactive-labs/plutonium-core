module Plutonium
  module Core
    module Fields
      module Renderers
        class AssociationRenderer < BasicRenderer
          attr_reader :reflection

          def initialize(name, reflection:, **user_options)
            @reflection = reflection
            super(name, **user_options)
          end

          def render(view_context, record)
            value = record.send(name)
            options = self.options.merge(helper: value.class.include?(Plutonium::Resource::Record) ? :display_association_value : :display_name_of)
            view_context.display_field value:, **options
          end
        end
      end
    end
  end
end
