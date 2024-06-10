module Plutonium
  module Core
    module Fields
      module Renderers
        class AssociationRenderer < Base
          attr_reader :reflection

          def initialize(name, reflection:, **user_options)
            @reflection = reflection
            super(name, **user_options)
          end

          def render
            display_field value:, **options
          end

          private

          def renderer_options
            {
              helper: value.class.include?(Plutonium::Resource::Record) ? :display_association_value : :display_name_of
            }
          end
        end
      end
    end
  end
end
