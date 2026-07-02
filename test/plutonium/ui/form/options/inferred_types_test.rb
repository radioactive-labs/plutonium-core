# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Options::InferredTypesTest < ActiveSupport::TestCase
  # Harness mirroring the form builder's inference chain: a base providing the
  # phlexi-form fallback, with Plutonium's overrides layered on top.
  class Harness
    module Fallback
      def infer_field_component
        @fallback
      end
    end

    include Fallback
    include Plutonium::UI::Form::Options::InferredTypes

    attr_accessor :inferred_field_type, :inferred_string_field_type, :object, :key

    def initialize(fallback: :__phlexi_fallback__, string_type: nil, field_type: nil, object: Object.new, key: :anything)
      @fallback = fallback
      @inferred_string_field_type = string_type
      @inferred_field_type = field_type
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

  test "has_cents decimal accessors infer the currency input" do
    harness = Harness.new(field_type: :decimal, object: MoneyModel.new, key: :amount)
    assert_equal :currency, harness.component
  end

  test "non-has_cents decimals are unaffected" do
    harness = Harness.new(fallback: :number, field_type: :decimal, object: MoneyModel.new, key: :weight)
    assert_equal :number, harness.component
  end

  test "models without has_cents do not raise" do
    assert_equal :__phlexi_fallback__, Harness.new(field_type: :decimal).component
  end

  test "a password field still wins over currency (security first)" do
    # Even if some odd has_cents attr were secret-named, masking takes priority.
    harness = Harness.new(string_type: :password, object: MoneyModel.new, key: :amount)
    assert_equal :password, harness.component
  end

  test "select still upgrades to slim_select" do
    assert_equal :slim_select, Harness.new(fallback: :select).component
  end

  test "boolean still upgrades to the toggle" do
    assert_equal :toggle, Harness.new(fallback: :boolean).component
  end
end
