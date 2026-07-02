# frozen_string_literal: true

require "test_helper"

# The intl-tel-input field forwards library options (e.g. initialCountry) to its
# Stimulus controller via a data value, so a bare local number for the chosen
# country is accepted instead of showing "No country selected".
#
# KitchenSinkDefinition declares: input :phone, as: :phone, initial_country: "gh"
class AdminPortal::IntlTelInputOptionsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  test "phone field emits the intl-tel-input options value with initialCountry" do
    get "/admin/kitchen_sinks/new"

    assert_response :success
    assert_match(/data-intl-tel-input-options-value="[^"]*initialCountry[^"]*gh/, response.body,
      "expected the phone field to forward initialCountry: gh to the Stimulus controller")
  end

  test "the initial_country option does not leak onto the input element" do
    get "/admin/kitchen_sinks/new"

    assert_response :success
    refute_includes response.body, "initial_country=",
      "the initial_country option must be consumed, not rendered as an HTML attribute"
  end
end
