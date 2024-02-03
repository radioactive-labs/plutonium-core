module Plutonium
  module Core
    module Fields
      module Inputs
        extend ActiveSupport::Autoload

        def self.build(name, type:, **)
          # type ||= :slim_select if options.key? :collection

          case type
          when :belongs_to
            Plutonium::Core::Fields::Inputs::BelongsToInput.new(name, **)
          when :has_one
            Plutonium::Core::Fields::Inputs::NoopInput.new
          when :has_many
            Plutonium::Core::Fields::Inputs::HasManyInput.new(name, **)
          else
            Plutonium::Core::Fields::Inputs::BasicInput.new(name, **)
          end
        end

        def self.infer_for_resource_attribute(resource_class, attr_name, **options)
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

        eager_autoload do
          autoload :AssociationInput
          autoload :BasicInput
          autoload :BelongsToInput
          autoload :HasManyInput
          autoload :NoopInput
        end
      end
    end
  end
end
