# frozen_string_literal: true

module Plutonium
  module Definition
    # Classless structured inputs: a group of fields collected into a hash
    # (single) or an array of hashes (when `repeat:` is given). Mixed into both
    # resource definitions and interactions.
    #
    # @example
    #   structured_input :address do |f|
    #     f.input :street
    #     f.input :city
    #   end
    #
    #   structured_input :contacts, repeat: 10 do |f|
    #     f.input :label
    #     f.input :phone_number
    #   end
    module StructuredInputs
      extend ActiveSupport::Concern

      # Holder built per render from a structured_input block. Reuses the same
      # field/input DSL as the rest of Plutonium definitions.
      class FieldsDefinition
        include Plutonium::Definition::DefineableProps

        defineable_props :field, :input
      end

      class_methods do
        # @option options [Integer, true] :repeat  presence => array; Integer => max rows
        # @option options [Class] :using  a FieldsDefinition-like class instead of a block
        # @option options [Array<Symbol>] :fields  restrict rendered fields
        def structured_input(name, **options, &block)
          unless block || options[:using]
            raise ArgumentError,
              "`structured_input :#{name}` needs a block or `using:` — e.g. " \
              "`structured_input :#{name} do |f| f.input :field end` or " \
              "`structured_input :#{name}, using: #{name.to_s.classify}Fields`"
          end

          defined_structured_inputs[name] = {options:, block:}.compact
        end

        def defined_structured_inputs
          @defined_structured_inputs ||= {}
        end

        def inherited(subclass)
          super
          subclass.instance_variable_set(
            :@defined_structured_inputs,
            defined_structured_inputs.deep_dup
          )
        end
      end

      # Instance access mirrors the defineable_prop convention (where
      # `defined_<plural>` is available on instances). The form's render path and
      # the param cleaner both hold a definition instance, so they read the
      # registry through here.
      def defined_structured_inputs
        self.class.defined_structured_inputs
      end
    end
  end
end
