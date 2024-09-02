module Plutonium
  module Definition
    module ConfigAttr
      extend ActiveSupport::Concern

      class_methods do
        def config_attr(*names)
          names.each do |name|
            define_singleton_method(name) do |value = :__this_is_so_nilly__|
              if value == :__this_is_so_nilly__
                # Getter behavior
                # if singleton_class.instance_variable_defined?(:"@#{name}")
                singleton_class.instance_variable_get(:"@#{name}")
                # end
              else
                # Setter behavior
                singleton_class.instance_variable_set(:"@#{name}", value)
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
