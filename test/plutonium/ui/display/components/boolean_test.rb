# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Display::Components::BooleanTest < ActiveSupport::TestCase
  Boolean = Plutonium::UI::Display::Components::Boolean

  # The default DisplaysValue#normalize_value stringifies, which turns `false`
  # into the truthy string "false" — the component would then render every
  # value as the "true" branch. We override normalize_value to keep the real
  # boolean; this is the regression guard.

  test "normalize_value keeps false as false (not the truthy string)" do
    component = Boolean.allocate
    assert_equal false, component.send(:normalize_value, false)
  end

  test "normalize_value keeps true as true" do
    component = Boolean.allocate
    assert_equal true, component.send(:normalize_value, true)
  end
end
