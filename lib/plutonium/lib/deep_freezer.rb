# frozen_string_literal: true

module Plutonium
  module Lib
    class DeepFreezer
      def self.freeze(object)
        #  Recursive calling #deep_freeze for enumerable objects.
        if object.respond_to? :each
          if object.instance_of?(Hash)
            object.each { |key, val| freeze(val) }
          else
            object.each { |val| freeze(val) }
          end
        end

        # #  Freezing of all instance variable values.
        # object.instance_variables.each do |var|
        #   frozen_val = instance_variable_get(var)
        #   frozen_val.deep_freeze
        #   instance_variable_set(var, frozen_val)
        # end

        if object.frozen?
          object
        else
          object.freeze
        end
      end
    end
  end
end
