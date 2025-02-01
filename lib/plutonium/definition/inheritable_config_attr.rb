module Plutonium
  module Definition
    module InheritableConfigAttr
      extend ActiveSupport::Concern

      class_methods do
        def inheritable_config_attr(*names)
          names.each do |name|
            # Create the underlying class_attribute
            attr_name = :"#{name}_config"
            class_attribute attr_name, instance_reader: true, instance_accessor: false, default: nil

            # Define class-level method that acts as both getter/setter
            define_singleton_method(name) do |value = :__not_set__|
              if value == :__not_set__
                # Getter behavior
                public_send(:"#{attr_name}")
              else
                # Setter behavior
                public_send(:"#{attr_name}=", value)
              end
            end

            # Instance-level method
            define_method(name) do
              self.class.send(name)
            end
          end
        end
      end
    end
  end
end
