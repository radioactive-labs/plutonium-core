# frozen_string_literal: true

require "test_helper"

# Integration tests for type-aware rendering of the kanban/grid card `meta` slot.
#
# The meta slot renders each field as a colored badge. Historically it applied
# `value.to_s.humanize` to every field, which mangled non-string types:
#   - a has_cents money field badged its raw decimal ("1234.56")
#   - a belongs_to association badged the object inspect ("#<User:0x...>"),
#     which also churned the decorative badge color every render because the
#     inspect string embeds a per-object memory address.
#
# KitchenSinkDefinition's kanban board declares:
#   card_fields header: :name, meta: [:status, :plan, :tier, :price, :user]
#
# so the meta slot must format the has_cents `price` as currency and the `user`
# association as its label, while enums (status/plan/tier) still humanize.
class AdminPortal::KanbanMetaFormattingTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @org = Organization.create!(name: "Meta Org #{SecureRandom.hex(4)}")
    @user = create_user!
    @sink = KitchenSink.create!(
      name: "Priced Card",
      status: :active,
      organization: @org,
      user: @user,
      price: 1234.56
    )
  end

  teardown { KitchenSink.delete_all }

  test "has_cents field in a meta badge renders as formatted currency" do
    get "/admin/kitchen_sinks?view=kanban&column=active"

    assert_response :success
    assert_includes response.body, "1,234.56",
      "expected the has_cents price to render as formatted currency in the meta badge"
  end

  # KitchenSink declares `has_cents :price_cents, unit: "$"`. The card currency
  # path reads that configured unit (no explicit display unit is threaded to the
  # card), so the badge shows the symbol rather than a bare number.
  test "has_cents unit drives the currency symbol on the card" do
    get "/admin/kitchen_sinks?view=kanban&column=active"

    assert_response :success
    assert_includes response.body, "$1,234.56",
      "expected the has_cents unit to prefix the currency symbol on the card"
  end

  test "association in a meta badge renders as its label, not an object inspect" do
    get "/admin/kitchen_sinks?view=kanban&column=active"

    assert_response :success
    refute_includes response.body, "#&lt;User",
      "the user association must not render as an object inspect in the meta badge"
    assert_includes response.body, @user.to_label,
      "expected the user association to render as its display label"
  end

  test "enum values in meta still humanize into badges" do
    get "/admin/kitchen_sinks?view=kanban&column=active"

    assert_response :success
    assert_includes response.body, "pu-badge"
    assert_includes response.body, "Active"
  end
end
