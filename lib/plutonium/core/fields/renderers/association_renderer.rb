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

          private

          def renderer_options
            resource_record = reflection.klass.include? Plutonium::Resource::Record
            {
              helper: resource_record ? :display_association_value : :display_name_of
            }
          end
        end
      end
    end
  end
end
