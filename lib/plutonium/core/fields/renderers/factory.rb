require "simple_form/map_type"

module Plutonium
  module Core
    module Fields
      module Renderers
        class Factory
          extend ::SimpleForm::MapType

          map_type :belongs_to, :has_one, :has_many, to: Plutonium::Core::Fields::Renderers::AssociationRenderer
          map_type :attachment, to: Plutonium::Core::Fields::Renderers::AttachmentRenderer
          map_type :map, to: Plutonium::Core::Fields::Renderers::MapRenderer

          def self.build(name, type:, **)
            mapping = mappings[type] || Plutonium::Core::Fields::Renderers::BasicRenderer
            mapping.new(name, **)
          end

          def self.for_resource_attribute(resource_class, attr_name, **options)
            type = nil
            options[:label] ||= resource_class.human_attribute_name(attr_name)

            if (attachment = resource_class.try(:reflect_on_attachment, attr_name))
              type = :attachment
              options[:reflection] = attachment
            elsif (association = resource_class.try(:reflect_on_association, attr_name))
              type = association.macro
              options[:reflection] = association
            elsif (column = resource_class.try(:column_for_attribute, attr_name))
              type = column.type
            end

            build(attr_name, type:, **options)
          end
        end
      end
    end
  end
end
