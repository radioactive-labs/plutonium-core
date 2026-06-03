# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Display::Components::CurrencyTest < ActiveSupport::TestCase
  Currency = Plutonium::UI::Display::Components::Currency

  # resolved_unit reads @unit; build a component with just that ivar set so we
  # can exercise the resolution logic without a full render context.
  def component_with(unit:, object: nil)
    c = Currency.allocate
    c.instance_variable_set(:@unit, unit)
    if object
      field = Struct.new(:object).new(object)
      c.define_singleton_method(:field) { field }
    end
    c
  end

  test "defaults to no symbol when no unit is given" do
    assert_equal "", component_with(unit: nil).send(:resolved_unit)
  end

  test "uses a literal string unit verbatim" do
    assert_equal "£", component_with(unit: "£").send(:resolved_unit)
  end

  test "reads a symbol unit off the record for per-row currencies" do
    record = Struct.new(:currency_symbol).new("€")
    component = component_with(unit: :currency_symbol, object: record)
    assert_equal "€", component.send(:resolved_unit)
  end

  test "normalize_value preserves the numeric value" do
    assert_in_delta 12.5, component_with(unit: nil).send(:normalize_value, 12.5), 0.0001
  end
end
