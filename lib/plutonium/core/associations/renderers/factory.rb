require "simple_form/map_type"

module Plutonium
  module Core
    module Associations
      module Renderers
        class Factory
          extend ::SimpleForm::MapType

          map_type :has_many, to: Plutonium::Core::Associations::Renderers::HasManyRenderer

          def self.build(name, type:, **)
            mapping = mappings[type]
            raise ArgumentError, "Unknown association renderer type #{type}" unless mapping.present?

            mapping.new(name, **)
          end

          def self.for_resource_association(resource_class, attr_name, **options)
            association = resource_class.try(:reflect_on_association, attr_name)
            raise ArgumentError, "#{attr_name} is not a valid association of #{resource_class}" unless association.present?
            raise ArgumentError, "#{association.klass} does is not a resource record" unless association.klass.include?(Plutonium::Resource::Record)

            type = association.macro
            raise NotImplementedError, "#{macro} associations are currently not supported." unless type == :has_many

            options[:reflection] = association
            build(attr_name, type:, **options)
          end
        end
      end
    end
  end
end
