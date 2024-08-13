require "test_helper"

module Plutonium
  module Models
    class HasCentsTest < Minitest::Test
      class TestModel
        include ActiveModel::Model
        include ActiveModel::Attributes
        include ActiveModel::Validations
        include ActiveModel::Validations::Callbacks
        include Plutonium::Models::HasCents

        attribute :price_cents, :integer
        attribute :cost_cents, :integer
        attribute :suffix, :integer
        attribute :custom_suffix, :integer

        has_cents :price_cents
        has_cents :cost_cents, name: :wholesale_price, rate: 1000
        has_cents :suffix
        has_cents :custom_suffix, suffix: "attr"

        validates :price_cents, numericality: {greater_than_or_equal_to: 0}
      end

      def setup
        @model = TestModel.new
      end

      def test_has_cents_attributes
        expected = {
          price_cents: {name: :price, rate: 100},
          cost_cents: {name: :wholesale_price, rate: 1000},
          suffix: {name: :suffix_amount, rate: 100},
          custom_suffix: {name: :custom_suffix_attr, rate: 100}
        }
        assert_equal expected, TestModel.has_cents_attributes
      end

      def test_has_cents_attribute
        assert TestModel.has_cents_attribute?(:price_cents)
        assert TestModel.has_cents_attribute?(:cost_cents)
        refute TestModel.has_cents_attribute?(:name)
      end

      def test_getter_methods
        @model.price_cents = 1099
        @model.cost_cents = 5000

        assert_equal 10.99, @model.price
        assert_equal 5.0, @model.wholesale_price
      end

      def test_setter_methods
        @model.price = 10.99
        @model.wholesale_price = 5.0

        assert_equal 1099, @model.price_cents
        assert_equal 5000, @model.cost_cents
      end

      def test_validation_inheritance
        @model.price = -10.99
        refute @model.valid?
        assert_includes @model.errors[:price_cents], "must be greater than or equal to 0"
        assert_includes @model.errors[:price], "must be greater than or equal to 0"
      end

      def test_custom_rate
        @model.wholesale_price = 10.5
        assert_equal 10500, @model.cost_cents
      end

      def test_nil_values
        @model.price = nil
        assert_nil @model.price_cents
        assert_nil @model.price
      end

      def test_zero_values
        @model.price = 0
        assert_equal 0, @model.price_cents
        assert_equal 0, @model.price
      end

      def test_rounding
        @model.price = 10.999
        assert_equal 1099, @model.price_cents
        assert_equal 10.99, @model.price
      end

      def test_large_numbers
        @model.price = 1_000_000.00
        assert_equal 100_000_000, @model.price_cents
        assert_equal 1_000_000.00, @model.price
      end

      def test_error_propagation
        @model.price_cents = -100
        @model.valid?
        assert_equal @model.errors[:price_cents], @model.errors[:price]
      end

      def test_multiple_validations
        TestModel.class_eval do
          validates :price_cents, presence: true
        end

        @model.price_cents = nil
        refute @model.valid?
        assert_includes @model.errors[:price_cents], "can't be blank"
        assert_includes @model.errors[:price], "can't be blank"
      end

      def test_custom_validation_error_message
        TestModel.class_eval do
          validates :price_cents, numericality: {greater_than: 0, message: "must be positive"}
        end

        @model.price = 0
        refute @model.valid?
        assert_includes @model.errors[:price_cents], "must be positive"
        assert_includes @model.errors[:price], "must be positive"
      end

      def test_suffix
        @model.suffix_amount = 10.5
        assert_equal 1050, @model.suffix
        assert_equal 10.5, @model.suffix_amount
      end

      def test_custom_suffix
        @model.custom_suffix_attr = 10.5
        assert_equal 1050, @model.custom_suffix
        assert_equal 10.5, @model.custom_suffix_attr
      end
    end
  end
end
