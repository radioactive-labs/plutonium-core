require "simple_form/map_type"

module Plutonium
  module Core
    module Fields
      module Inputs
        class Factory
          extend ::SimpleForm::MapType

          map_type :has_one, to: Plutonium::Core::Fields::Inputs::NoopInput
          map_type :belongs_to, to: Plutonium::Core::Fields::Inputs::BelongsToAssociationInput
          map_type :polymorphic_belongs_to, to: Plutonium::Core::Fields::Inputs::PolymorphicBelongsToAssociationInput
          map_type :has_many, to: Plutonium::Core::Fields::Inputs::HasManyAssociationInput
          map_type :attachment, to: Plutonium::Core::Fields::Inputs::AttachmentInput
          map_type :datetime, :date, :time, to: Plutonium::Core::Fields::Inputs::DateTimeInput
          map_type :phone, to: Plutonium::Core::Fields::Inputs::PhoneInput
          # map_type :text, :string, to: Plutonium::Core::Fields::Inputs::SimpleFormInput

          def self.build(name, type:, **options)
            input_type = options[:as] || type
            mapping = mappings[input_type] || Plutonium::Core::Fields::Inputs::SimpleFormInput
            mapping.new(name, **options)
          end

          def self.for_resource_attribute(resource_class, attr_name, **options)
            type = nil

            if (attachment = resource_class.try(:reflect_on_attachment, attr_name))
              type = :attachment
              options[:reflection] = attachment
            elsif (association = resource_class.try(:reflect_on_association, attr_name))
              type = association.polymorphic? ? :"polymorphic_#{association.macro}" : association.macro
              options[:reflection] = association
            elsif (column = resource_class.try(:column_for_attribute, attr_name))
              type = column.type
              options[:multiple] = column.try(:array?) if options[:multiple].nil?
            elsif (filter = resource_class.try(:filters).try(:[], attr_name))
              # type = filter.database_column_type
              options[:hint] ||= filter.desc
              options[:multiple] = column.try(:array?) if options[:multiple].nil?
            end

            build(attr_name, type:, **options)
          end
        end
      end
    end
  end
end
