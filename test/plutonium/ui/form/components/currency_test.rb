# frozen_string_literal: true

require "test_helper"

# Unit tests for the currency input's unit-prefix resolution. The prefix reuses
# the display's {Currency.resolve_unit} chain (explicit unit -> has_cents ->
# config/i18n default), strips `unit:` off the attributes so it can't leak onto
# the <input>, and returns "" when there's nothing to show.
class Plutonium::UI::Form::Components::CurrencyTest < ActiveSupport::TestCase
  Component = Plutonium::UI::Form::Components::Currency

  FakeField = Struct.new(:object, :key)

  def prefix_for(attrs, object: Object.new, key: :price)
    component = Component.allocate
    component.instance_variable_set(:@attributes, attrs)
    component.instance_variable_set(:@field, FakeField.new(object, key))
    prefix = component.send(:resolve_unit_prefix)
    [prefix, attrs]
  end

  test "an explicit unit is used as the prefix" do
    prefix, = prefix_for({unit: "£"})
    assert_equal "£", prefix
  end

  test "unit: false renders no prefix" do
    prefix, = prefix_for({unit: false})
    assert_equal "", prefix
  end

  test "reads the record's has_cents unit when no explicit unit is given" do
    record = Object.new
    def record.has_cents_unit_for(key) = (key == :price) ? "€" : nil
    prefix, = prefix_for({}, object: record)
    assert_equal "€", prefix
  end

  test "falls back to the configured default_currency_unit" do
    previous = Plutonium.configuration.default_currency_unit
    Plutonium.configuration.default_currency_unit = "R"
    prefix, = prefix_for({})
    assert_equal "R", prefix
  ensure
    Plutonium.configuration.default_currency_unit = previous
  end

  test "the unit attribute is stripped so it never lands on the input" do
    _prefix, attrs = prefix_for({unit: "£", class: "x"})
    refute attrs.key?(:unit)
    assert attrs.key?(:class), "unrelated attributes are left intact"
  end
end
