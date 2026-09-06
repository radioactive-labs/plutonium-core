# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Backwards-compat smoke (test plan §2.5 step 5): with the default unscoped
# `filter :category, with: :association, class_name: "Catalog::Category"` that
# ships in `Catalog::ProductDefinition`, the filter STILL narrows results and
# renders a pill naming whatever category id the user supplied — the
# pre-4bbe82b4 behavior is preserved for unscoped filters. Pre-fix nothing
# enforced a scope, so every id resolved and rendered; the leak was that the
# SAME code widened past an additionally-configured scope. With no scope set,
# there's nothing to widen past — every category name is fair game.
class AssociationUnscopedBackwardsCompatHtmlTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!(status: :verified)
    create_membership!(organization: @org, user: @user)

    @any_cat = create_category!(name: "Any Category")
    create_product!(
      name: "Tagged With Any Category",
      category: @any_cat,
      user: @user,
      organization: @org,
      status: :active
    )

    login_as(@user, portal: :user)
  end

  def products_index_url
    "/org/#{@org.to_param}/catalog/products"
  end

  def filter_pills_html(body)
    pattern = %r{data-bulk-actions-target="filterPills"[^>]*>(.*?)</div>}m
    match = body.match(pattern)
    match ? match[1] : ""
  end

  def test_unscoped_filter_renders_pill_for_any_category_id
    get products_index_url, params: {"q[category][value]" => @any_cat.to_sgid.to_s}, env: {}
    assert_response :success
    pills = filter_pills_html(response.body)

    # The unscoped filter accepts any category id and renders its label.
    # This is the unchanged pre-4bbe82b4 behaviour: no scope narrowing
    # configured → no leak → no widening.
    assert_includes pills, "Category: Any Category",
      "unscoped filter should still render a pill for any category id"
    assert_includes response.body, "Tagged With Any Category"
  end
end
