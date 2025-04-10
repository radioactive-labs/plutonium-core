module Plutonium
  module Definition
    module NestedInputs
      extend ActiveSupport::Concern

      included do
        defineable_prop :nested_input

        # def self.nested_input(name, with: nil, **)
        #   defined_nested_inputs[name] = {}
        # end

        # def nested_input(name, with: nil, **)
        #   instance_defined_nested_inputs[name] = {}
        # end
      end

      class_methods do
        # Dynamically defines writer and reader methods for handling nested
        # attributes in form objects or interaction classes, mimicking the
        # behavior of ActiveRecord's `accepts_nested_attributes_for`.
        #
        # This method allows you to pass in nested data (e.g. from a form) and
        # automatically build or destroy associated records based on that input.
        #
        # === Example 1: Basic usage with default naming
        #   # If `Contact` is the associated model inferred from the
        #   `:contacts` association:
        #
        #   `accepts_nested_attributes_for :contacts`
        #
        # === Example 2: When association name and model name differ
        #   Suppose the `User` model has a `has_many :contacts` association
        #   pointing to a `UserContactInfo` model. You need to specify the
        #   model name.
        #
        #   `accepts_nested_attributes_for :contacts, class_name: "UserAddress"`
        #
        # This macro defines:
        #   - `contacts_attributes=` — used to assign nested attributes,
        #     including support for `_destroy`
        #   - `contacts_attributes` — returns the current attributes of
        #     associated records
        #
        # @param association [Symbol] The association name. (e.g., `:contacts`).
        # @param class_name [String, nil] Required if association reflection
        # is needed to determine the associated model class (e.g. when the
        # association name doesn't match the class name).
        # @param reject_if [Proc, Symbol, nil] Used to skip building association
        #   records when the condition returns true.
        def accepts_nested_attributes_for(
          association,
          class_name: nil,
          reject_if: nil
        )
          destroy_values = [1, "1", "true", true]

          should_destroy = ->(value) { destroy_values.include?(value) }

          should_reject =
            lambda do |attrs|
              case reject_if
              when Symbol
                send(reject_if, attrs)
              when Proc
                reject_if.call(attrs)
              else
                false
              end
            end

          define_method("#{association}_attributes=") do |attributes|
            result =
              case attributes
              when Hash
                attrs = attributes.except(:_destroy)
                unless should_destroy.call(attributes[:_destroy]) ||
                         should_reject.call(attrs)
                  assoc_class.new(attrs)
                end
              when Array
                attributes.filter_map do |attrs|
                  unless should_destroy.call(attrs[:_destroy]) ||
                           should_reject.call(attrs)
                    assoc_class.new(attrs.except(:_destroy))
                  end
                end
              end

            send("#{association}=", result)
          end

          define_method("#{association}_attributes") do
            Array(send(association)).map(&:attributes)
          end
        end
      end
    end
  end
end
