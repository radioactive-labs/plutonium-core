module Plutonium
  module Core
    module Fields
      module Inputs
        class AssociationInput < Plutonium::Core::Fields::Input
          def render(f, record)
            f.association name, **options
          end

          private

          def reflection = resource_class.reflect_on_association(name)

          def param
            case reflection.macro
            when :belongs_to
              (reflection.respond_to?(:options) && reflection.options[:foreign_key]) || :"#{reflection.name}_id"
            when :has_one
              raise ArgumentError, ":has_one associations are not currently supported"
            else
              :"#{reflection.name.to_s.singularize}_ids"
            end
          end
        end
      end
    end
  end
end
