# frozen_string_literal: true

require "test_helper"

# phlexi's Number coerces through Float(), dropping a decimal column's scale
# (10.50 shows as 10.5) and precision past ~15 significant digits.
class Plutonium::UI::Display::Components::NumberTest < ActiveSupport::TestCase
  def render_number(record, key, **attributes)
    Plutonium::UI::Display::Base.new(record).field(key).component_for(nil, **attributes).call
  end

  test "a decimal column keeps its scale" do
    assert_includes render_number(KitchenSink.new(balance: "1999.5"), :balance), "1,999.50"
  end

  test "a decimal keeps digits a Float would round away" do
    record = KitchenSink.new(balance: BigDecimal("1234567890123456.78"))

    assert_includes render_number(record, :balance), "1,234,567,890,123,456.78"
  end

  test "explicit number options still win" do
    assert_includes render_number(KitchenSink.new(balance: "1999.5"), :balance, options: {delimiter: " "}), "1 999.5"
  end

  test "integers are unaffected" do
    assert_includes render_number(KitchenSink.new(age: 4200), :age), "4,200"
  end
end
