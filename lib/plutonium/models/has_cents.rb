# frozen_string_literal: true

module Plutonium
  module Models
    # HasCents module provides functionality to handle monetary values stored as cents
    # and expose them as decimal values. It also ensures that validations applied to
    # the cents attribute are inherited by the decimal attribute.
    #
    # @example Usage
    #   class Product < ApplicationRecord
    #     include Plutonium::Models::HasCents
    #
    #     has_cents :price_cents
    #     has_cents :cost_cents, name: :wholesale_price, rate: 1000
    #     has_cents :quantity_cents, name: :quantity, rate: 1
    #     has_cents :total_cents, suffix: "value"
    #
    #     validates :price_cents, numericality: { greater_than_or_equal_to: 0 }
    #   end
    #
    # @example Basic Usage
    #   product = Product.new(price: 10.99)
    #
    #   product.price_cents #=> 1099
    #   product.price #=> 10.99
    #
    #   product.wholesale_price = 5.5
    #   product.cost_cents #=> 5500
    #
    #   product.quantity = 3
    #   product.quantity_cents #=> 3
    #
    # @example Truncation
    #   product.price = 10.991
    #   product.price_cents #=> 1099
    #
    #   product.price = 10.995
    #   product.price_cents #=> 1099
    #
    #   product.price = 10.999
    #   product.price_cents #=> 1099
    #
    #   product.total_value = 100.50
    #   product.total_cents #=> 10050
    #
    # @example Validation Inheritance
    #   product = Product.new(price: -10.99)
    #   product.valid? #=> false
    #   product.errors[:price_cents] #=> ["must be greater than or equal to 0"]
    #   product.errors[:price] #=> ["is invalid"]
    #
    # @example Reflection
    #   Product.has_cents_attributes
    #   #=> {
    #   #     price_cents: { name: :price, rate: 100 },
    #   #     cost_cents: { name: :wholesale_price, rate: 1000 },
    #   #     quantity_cents: { name: :quantity, rate: 1 },
    #   #     total_cents: { name: :total_value, rate: 100 }
    #   #   }
    #
    #   Product.has_cents_attribute?(:price_cents) #=> true
    #   Product.has_cents_attribute?(:name) #=> false
    #   Product.has_cents_attributes[:cost_cents] #=> {name: :wholesale_price, rate: 1000}
    #
    # @note This module automatically handles validation propagation. If a validation error
    #   is applied to the cents attribute, the decimal attribute will be marked as invalid.
    #
    # @note The module uses BigDecimal for internal calculations to ensure precision
    #   in monetary operations.
    #
    # @see ClassMethods#has_cents for details on setting up attributes
    module HasCents
      extend ActiveSupport::Concern

      included do
        class_attribute :has_cents_attributes, instance_writer: false, default: {}
      end

      module ClassMethods
        # # Inherit validations from cents attribute to decimal attribute
        # def validate(*args, &block)
        #   options = args.extract_options!
        #   Array(options[:attributes]).each do |attribute|
        #     attribute = attribute.to_sym
        #     if has_cents_attribute?(attribute)
        #       decimal_attribute = has_cents_attributes[attribute][:name]
        #       options[:attributes] += [decimal_attribute]
        #       args = args.map do |validator|
        #         if validator.respond_to?(:attributes)
        #           validator.instance_variable_set(:@attributes, validator.attributes + [decimal_attribute])
        #           _validators[decimal_attribute] << validator
        #           validator
        #         end
        #       end
        #     end
        #   end

        #   super(*args, options, &block)
        # end
        # Defines getter and setter methods for a monetary value stored as cents,
        # and ensures validations are applied to both cents and decimal attributes.
        #
        # @param cents_name [Symbol] The name of the attribute storing the cents value.
        # @param name [Symbol, nil] The name for the generated methods. If nil, it's derived from cents_name.
        # @param rate [Integer] The conversion rate from the decimal value to cents (default: 100).
        #   This represents how many cents are in one unit of the decimal value.
        #   For example:
        #   - rate: 100 for dollars/cents (1 dollar = 100 cents)
        #   - rate: 1000 for dollars/mils (1 dollar = 1000 mils)
        #   - rate: 1 for a whole number representation
        # @param suffix [String] The suffix to append to the cents_name if name is not provided (default: "amount").
        #
        # @example Standard currency (dollars and cents)
        #   has_cents :price_cents
        #
        # @example Custom rate for a different currency division
        #   has_cents :amount_cents, name: :cost, rate: 1000
        #
        # @example Whole number storage without decimal places
        #   has_cents :quantity_cents, name: :quantity, rate: 1
        #
        # @example Using custom suffix
        #   has_cents :total_cents, suffix: "value"
        def has_cents(cents_name, name: nil, rate: 100, suffix: "amount")
          cents_name = cents_name.to_sym
          name ||= cents_name.to_s.gsub(/_cents$/, "")
          name = name.to_sym
          name = (name == cents_name) ? :"#{cents_name}_#{suffix}" : name

          self.has_cents_attributes = has_cents_attributes.merge(
            cents_name => {name: name, rate: rate}
          )

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            # Getter method for the decimal representation of the cents value.
            #
            # @return [BigDecimal, nil] The decimal value or nil if cents_name is not present.
            def #{name}
              #{cents_name}.to_d / #{rate} if #{cents_name}.present?
            end

            # Setter method for the decimal representation of the cents value.
            #
            # @param value [Numeric, nil] The decimal value to be set.
            def #{name}=(value)
              self.#{cents_name} = if value.present?
                (BigDecimal(value.to_s) * #{rate}).to_i
              end
            end

            # Mark decimal field as invalid if cents field is not valid
            after_validation do
              next unless errors[#{cents_name.inspect}].present?

              errors.add(#{name.inspect}, :invalid)
            end
          RUBY
        end

        # Checks if a given attribute is defined with has_cents
        #
        # @param attribute [Symbol] The attribute to check
        # @return [Boolean] true if the attribute is defined with has_cents, false otherwise
        def has_cents_attribute?(attribute)
          has_cents_attributes.key?(attribute.to_sym)
        end
      end
    end
  end
end
