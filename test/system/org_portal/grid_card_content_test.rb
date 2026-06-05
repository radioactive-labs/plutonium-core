# frozen_string_literal: true

require "application_system_test_case"

# Grid cards format declared slot values by type instead of stringifying
# everything through display_name_of:
#   - enum metas render as colored Badge pills (draft -> warning, humanized)
#   - date slots (here: the created_at footer fallback) render timeago markup
#   - a blank *declared* slot renders an em-dash so cards keep an even height
#     rather than collapsing the line.
class OrgPortal::GridCardContentTest < ApplicationSystemTestCase
  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @category = create_category!
    # Catalog::ProductDefinition declares grid_fields(header: :name,
    # subheader: :description, meta: [:status]). The blank-description product
    # exercises the em-dash placeholder in the declared subheader slot.
    create_product!(category: @category, user: @user, organization: @org,
      name: "Described Widget", description: "A fine widget", status: :draft)
    create_product!(category: @category, user: @user, organization: @org,
      name: "Bare Widget", description: nil, status: :draft)
  end

  test "grid cards format slots by type: badge, timeago, blank placeholder" do
    visit "/org/#{@org.to_param}/catalog/products?view=grid"
    fill_in "login", with: @user.email
    click_button "Login"
    fill_in "password", with: "password123"
    click_button "Login"

    assert_selector ".pu-card", minimum: 2, wait: 5

    # Enum meta -> colored Badge pill (draft -> warning), humanized label.
    assert_selector ".pu-card .pu-badge.pu-badge-warning", text: "Draft", minimum: 2

    # Date footer (created_at fallback) -> timeago <time> markup.
    assert_selector ".pu-card time[data-controller='timeago']", minimum: 2

    # Blank declared subheader -> em-dash, not a collapsed/missing line.
    within find(".pu-card", text: "Bare Widget") do
      assert_text "—"
    end

    # Present subheader still shows the value, with no placeholder.
    within find(".pu-card", text: "Described Widget") do
      assert_text "A fine widget"
      assert_no_text "—"
    end
  end
end
