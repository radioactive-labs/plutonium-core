require 'simple_form/map_type'

module Plutonium
  module Core
    module Fields
      module Inputs
        class Factory
          extend ::SimpleForm::MapType

          map_type :has_one, to: Plutonium::Core::Fields::Inputs::NoopInput
          map_type :belongs_to, to: Plutonium::Core::Fields::Inputs::BelongsToInput
          map_type :has_many, to: Plutonium::Core::Fields::Inputs::HasManyInput

          def self.build(name, type:, **)
            mapping = mappings[type] || Plutonium::Core::Fields::Inputs::BasicInput
            mapping.new(name, **)

            # type ||= :slim_select if options.key? :collection

            # case type
            # when :belongs_to
            #   Plutonium::Core::Fields::Inputs::BelongsToInput.new(name, **)
            # when :has_one
            #   Plutonium::Core::Fields::Inputs::NoopInput.new
            # when :has_many
            #   Plutonium::Core::Fields::Inputs::HasManyInput.new(name, **)
            # else
            #   Plutonium::Core::Fields::Inputs::BasicInput.new(name, **)
            # end
          end

          def self.for_resource_attribute(resource_class, attr_name, **options)
            type = nil

            if (reflection = resource_class.try(:reflect_on_association, attr_name))
              type = reflection.macro
              options[:reflection] = reflection
            elsif (attachment = resource_class.try(:reflect_on_association, :"#{attr_name}_attachment"))
              type = :attachment
              options[:multiple] = attachment.macro == :has_many if options[:multiple].nil?
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
