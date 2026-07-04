# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Display::Components::CurrencyTest < ActiveSupport::TestCase
  Currency = Plutonium::UI::Display::Components::Currency

  # resolved_unit reads @unit; build a component with just that ivar set so we
  # can exercise the resolution logic without a full render context.
  def component_with(unit:, object: nil, key: nil)
    c = Currency.allocate
    c.instance_variable_set(:@unit, unit)
    # A component always renders within a field; model that even when the test
    # doesn't care about the record (object nil → no has_cents fallback).
    field = Struct.new(:object, :key).new(object, key)
    c.define_singleton_method(:field) { field }
    c
  end

  # A record that carries a has_cents unit config for :price.
  def record_with_has_cents_unit(unit)
    Class.new do
      include Plutonium::Models::HasCents

      define_method(:read_attribute) { |_| nil }
      # Minimal stand-in: register the decimal accessor + unit directly.
      self.has_cents_attributes = {price_cents: {name: :price, rate: 100, unit: unit}}
      def gbp_symbol = "$"
    end.new
  end

  test "defaults to the i18n currency unit when nothing is configured" do
    # No explicit unit, no has_cents unit, no config override → i18n default ($ in en).
    assert_equal "$", component_with(unit: nil).send(:resolved_unit)
  end

  test "a configured default_currency_unit overrides the i18n default" do
    with_default_currency_unit("€") do
      assert_equal "€", component_with(unit: nil).send(:resolved_unit)
    end
  end

  test "default_currency_unit of empty string opts back into no symbol" do
    with_default_currency_unit("") do
      assert_equal "", component_with(unit: nil).send(:resolved_unit)
    end
  end

  test "uses a literal string unit verbatim" do
    assert_equal "£", component_with(unit: "£").send(:resolved_unit)
  end

  test "an explicit false unit renders no symbol" do
    assert_equal "", component_with(unit: false).send(:resolved_unit)
  end

  test "a false has_cents unit renders no symbol (does not fall through to the default)" do
    record = record_with_has_cents_unit(false)
    component = component_with(unit: nil, object: record, key: :price)
    assert_equal "", component.send(:resolved_unit)
  end

  test "a false default_currency_unit renders no symbol" do
    with_default_currency_unit(false) do
      assert_equal "", component_with(unit: nil).send(:resolved_unit)
    end
  end

  test "reads a symbol unit off the record for per-row currencies" do
    record = Struct.new(:currency_symbol).new("€")
    component = component_with(unit: :currency_symbol, object: record)
    assert_equal "€", component.send(:resolved_unit)
  end

  test "normalize_value preserves the numeric value" do
    assert_in_delta 12.5, component_with(unit: nil).send(:normalize_value, 12.5), 0.0001
  end

  test "falls back to the record's has_cents unit when no explicit unit is given" do
    record = record_with_has_cents_unit("$")
    component = component_with(unit: nil, object: record, key: :price)
    assert_equal "$", component.send(:resolved_unit)
  end

  test "resolves a symbol has_cents unit off the record" do
    record = record_with_has_cents_unit(:gbp_symbol)
    component = component_with(unit: nil, object: record, key: :price)
    assert_equal "$", component.send(:resolved_unit)
  end

  test "explicit display unit takes precedence over the has_cents unit" do
    record = record_with_has_cents_unit("$")
    component = component_with(unit: "£", object: record, key: :price)
    assert_equal "£", component.send(:resolved_unit)
  end

  test "records without has_cents fall back to the default currency unit" do
    plain = Struct.new(:price).new(10)
    component = component_with(unit: nil, object: plain, key: :price)
    assert_equal "$", component.send(:resolved_unit)
  end

  private

  def with_default_currency_unit(value)
    previous = Plutonium.configuration.default_currency_unit
    Plutonium.configuration.default_currency_unit = value
    yield
  ensure
    Plutonium.configuration.default_currency_unit = previous
  end
end
