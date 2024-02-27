require "simple_form/map_type"

module Plutonium
  module Core
    module Fields
      module Inputs
        class Factory
          extend ::SimpleForm::MapType

          map_type :has_one, to: Plutonium::Core::Fields::Inputs::NoopInput
          map_type :belongs_to, to: Plutonium::Core::Fields::Inputs::BelongsToAssociationInput
          map_type :has_many, to: Plutonium::Core::Fields::Inputs::HasManyAssociationInput
          map_type :attachment, to: Plutonium::Core::Fields::Inputs::AttachmentInput

          def self.build(name, type:, **options)
            mapping = mappings[type]
            unless mapping.present?
              options[:as] = type
              mapping = Plutonium::Core::Fields::Inputs::SimpleFormInput
            end
            mapping.new(name, **options)
          end

          def self.for_resource_attribute(resource_class, attr_name, **options)
            type = nil

            if (attachment = resource_class.try(:reflect_on_attachment, attr_name))
              type = :attachment
              options[:reflection] = attachment
            elsif (association = resource_class.try(:reflect_on_association, attr_name))
              type = association.macro
              options[:reflection] = association
            elsif (column = resource_class.try(:column_for_attribute, attr_name))
              type = column.type
              options[:multiple] = column.try(:array?) if options[:multiple].nil?
            end

            build(attr_name, type:, **options)
          end
        end
      end
    end
  end
end
