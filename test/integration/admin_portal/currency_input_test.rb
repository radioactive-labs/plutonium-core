# frozen_string_literal: true

require "test_helper"

# The currency input (`as: :currency`) renders a number field with an optional
# unit prefix overlaid at its left edge. The unit resolves like the display:
# KitchenSink `has_cents :price_cents, unit: "$"`, so the price field shows "$"
# without an explicit `unit:` on the input.
#
# KitchenSinkDefinition declares a bare `input :price` — `price` is a has_cents
# accessor, so the currency input is INFERRED (no explicit `as: :currency`).
class AdminPortal::CurrencyInputTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  test "the currency field renders a number input" do
    get "/admin/kitchen_sinks/new"
    assert_response :success

    price_input = response.body[/<input[^>]*name="kitchen_sink\[price\]"[^>]*>/]
    assert price_input, "expected a price input on the form"
    assert_includes price_input, %(type="number")
    assert_includes price_input, %(inputmode="decimal")
  end

  test "the has_cents unit is overlaid as a prefix before the input" do
    get "/admin/kitchen_sinks/new"
    assert_response :success

    # The prefix <span> sits immediately before the price <input>, inside the
    # relative wrapper the component adds.
    assert_match(
      %r{<span[^>]*pointer-events-none[^>]*>\s*\$\s*</span>\s*<input[^>]*name="kitchen_sink\[price\]"}m,
      response.body,
      "expected a $ prefix span rendered right before the currency input"
    )
  end

  test "the unit option is consumed, not leaked onto the input element" do
    get "/admin/kitchen_sinks/new"
    assert_response :success

    price_input = response.body[/<input[^>]*name="kitchen_sink\[price\]"[^>]*>/]
    refute_includes price_input, "unit=",
      "the unit option must be consumed, not rendered as an HTML attribute"
  end
end
