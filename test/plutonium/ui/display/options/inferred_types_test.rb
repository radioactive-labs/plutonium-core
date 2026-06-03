# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Display::Options::InferredTypesTest < ActiveSupport::TestCase
  # Harness that mimics the builder's inference chain: a base providing the
  # phlexi-display fallback, with Plutonium's overrides layered on top.
  class Harness
    # Stands in for phlexi-display's infer_field_component (the `super` target).
    module Fallback
      def infer_field_component
        :__phlexi_fallback__
      end
    end

    include Fallback
    include Plutonium::UI::Display::Options::InferredTypes

    attr_accessor :inferred_field_type, :object, :key

    def initialize(type, object: Object.new, key: :anything)
      @inferred_field_type = type
      @object = object
      @key = key
    end

    def component
      send(:infer_field_component)
    end
  end

  # Model whose :amount accessor is a has_cents decimal pair.
  class MoneyModel
    def self.has_cents_decimal_attribute?(attr) = attr == :amount
  end

  test "boolean infers the boolean component (not the string fallback)" do
    assert_equal :boolean, Harness.new(:boolean).component
  end

  test "enum infers the badge component" do
    assert_equal :badge, Harness.new(:enum).component
  end

  test "attachment still infers the attachment component" do
    assert_equal :attachment, Harness.new(:attachment).component
  end

  test "unhandled types delegate to the phlexi-display fallback" do
    assert_equal :__phlexi_fallback__, Harness.new(:string).component
  end

  test "has_cents decimal accessors infer the currency component" do
    harness = Harness.new(:decimal, object: MoneyModel.new, key: :amount)
    assert_equal :currency, harness.component
  end

  test "non-has_cents decimals are unaffected" do
    harness = Harness.new(:decimal, object: MoneyModel.new, key: :weight)
    assert_equal :__phlexi_fallback__, harness.component
  end

  test "models without has_cents do not raise" do
    assert_equal :__phlexi_fallback__, Harness.new(:decimal).component
  end
end
