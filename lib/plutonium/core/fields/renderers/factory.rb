require "simple_form/map_type"

module Plutonium
  module Core
    module Fields
      module Renderers
        class Factory
          extend ::SimpleForm::MapType

          map_type :belongs_to, :has_one, :has_many, to: Plutonium::Core::Fields::Renderers::AssociationRenderer

          def self.build(name, type:, **)
            mapping = mappings[type] || Plutonium::Core::Fields::Renderers::BasicRenderer
            mapping.new(name, **)

            # type ||= :slim_select if options.key? :collection

            # case type
            # when :belongs_to, :has_one, :has_many
            #   Plutonium::Core::Fields::Renderers::AssociationRenderer.new(name, **)
            # else
            #   Plutonium::Core::Fields::Renderers::BasicRenderer.new(name, **)
            # end
          end

          def self.for_resource_attribute(resource_class, attr_name, **options)
            type = nil
            options[:label] ||= resource_class.human_attribute_name(attr_name)

            if resource_class.respond_to? :reflect_on_association
              attachment = resource_class.reflect_on_association(:"#{attr_name}_attachment") || \
                resource_class.reflect_on_association(:"#{attr_name}_attachments")
              association = resource_class.reflect_on_association(attr_name)
            end

            if attachment.present?
              type = :attachment
              options[:helper] = :display_attachment_value
              # options[:multiple] = (attachment.macro == :has_many) unless options.key?(:multiple)
            elsif association.present?
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
