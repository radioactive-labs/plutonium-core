# frozen_string_literal: true

module Plutonium
  module Lib
    class DeepFreezer
      def self.freeze(object)
        # Never freeze Class or Module objects - they have mutable state that Rails needs
        return object if object.is_a?(Class) || object.is_a?(Module)

        #  Recursive calling #deep_freeze for enumerable objects.
        if object.respond_to? :each
          if object.instance_of?(Hash)
            object.each { |key, val| freeze(val) }
          else
            object.each { |val| freeze(val) }
          end
        end

        if object.frozen?
          object
        else
          object.freeze
        end
      end
    end
  end
end
