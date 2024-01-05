module Plutonium
  module Builders
    class Associations
      attr_reader :record

      def initialize
        @associations = {} # using hash since keys act as an ordered set
        @definitions = {}
      end

      def with_record(record)
        @record = record
        self
      end

      def with_associations(*association_classes)
        association_classes.flatten.each do |association_class|
          define_association association_class unless association_defined? association_class
          @associations[association_class] = true
        end
        self
      end

      def define_association(association_class, label: nil)
        @definitions[association_class] = {label:}
        self
      end

      def only!(*associations)
        @associations.slice!(*associations.flatten)
        self
      end

      def except!(*associations)
        @associations.except!(*associations.flatten)
        self
      end

      def associations
        @definitions.slice(*@associations.keys)
      end

      def association_defined?(association_class)
        @definitions.key? association_class
      end
    end
  end
end
