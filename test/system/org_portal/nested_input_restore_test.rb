# frozen_string_literal: true

require "application_system_test_case"

# Removing a persisted nested row collapses it to a "Removed — Restore" bar and
# flags it for destruction; Restore brings the row back and clears the flag.
class OrgPortal::NestedInputRestoreTest < ApplicationSystemTestCase
  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @category = create_category!
    @product = create_product!(category: @category, user: @user, organization: @org, status: :draft)
    @variant = create_variant!(product: @product, name: "Midnight Black")
  end

  test "remove collapses a persisted nested row to a restorable bar, then restore brings it back" do
    visit "/org/#{@org.to_param}/catalog/products/#{@product.id}/edit"
    fill_in "login", with: @user.email
    fill_in "password", with: "password123"
    click_button "Login"

    # The variant row renders with its fields visible.
    assert_selector :field, with: "Midnight Black"
    fieldset = find(:field, with: "Midnight Black").find(:xpath, "ancestor::fieldset[1]")
    destroy = fieldset.find("input[name*='_destroy']", visible: :all)
    assert_equal "false", destroy.value

    # Remove → fields hidden, "Removed" bar shown, _destroy flagged.
    within(fieldset) { click_button "Remove" }
    within(fieldset) { assert_text "Removed" }
    assert_no_selector :field, with: "Midnight Black"
    assert_equal "1", destroy.value

    # Restore → fields back, flag cleared.
    within(fieldset) { click_button "Restore" }
    assert_selector :field, with: "Midnight Black"
    assert_equal "0", destroy.value
  end
end
