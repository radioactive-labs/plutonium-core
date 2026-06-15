# frozen_string_literal: true

require "test_helper"

class AdminPortal::FormLayoutRenderingTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  test "renders section headings and groups fields" do
    get "/admin/kitchen_sinks/new"
    assert_response :success
    assert_includes response.body, "Identity"
    assert_includes response.body, "Who this is"
    assert_includes response.body, "Everything else"
    assert_includes response.body, %(name="kitchen_sink[name]")
    assert_includes response.body, %(name="kitchen_sink[favorite_color]")
  end

  test "collapsible section renders a details element" do
    get "/admin/kitchen_sinks/new"
    assert_match(/<details[^>]*\bopen\b/, response.body)
    assert_includes response.body, "<summary"
  end

  test "a dynamic collapsed: proc is resolved in the record context" do
    # :appearance declares `collapsed: -> { object.persisted? }`.
    # New record → not persisted → the Appearance <details> is open.
    get "/admin/kitchen_sinks/new"
    new_tag = response.body.match(/(<details[^>]*>)\s*<summary[^>]*>\s*Appearance/m)
    assert new_tag, "expected a collapsible Appearance <details>"
    assert_includes new_tag[1], "open", "Appearance should be open for a new record"

    # Existing record → persisted → same section renders collapsed (no `open`).
    org = Organization.create!(name: "Sink Org #{SecureRandom.hex(4)}")
    sink = KitchenSink.create!(name: "Sink", organization: org)
    get "/admin/kitchen_sinks/#{sink.id}/edit"
    assert_response :success
    edit_tag = response.body.match(/(<details[^>]*>)\s*<summary[^>]*>\s*Appearance/m)
    assert edit_tag, "expected a collapsible Appearance <details>"
    refute_includes edit_tag[1], "open", "Appearance should be collapsed for a persisted record"
  end

  test "a section with a falsey condition renders nothing and withholds its fields" do
    get "/admin/kitchen_sinks/new"
    assert_response :success
    refute_includes response.body, "Secret stuff"
    refute_includes response.body, %(name="kitchen_sink[secret_token]")
  end

  test "a section whose fields are all absent from the permitted set renders nothing" do
    get "/admin/kitchen_sinks/new"
    assert_response :success
    # :all_absent lists only :never_permitted, which is never in the permitted
    # set, so the section resolves to zero fields — no heading, no chrome.
    refute_includes response.body, "All Absent Section"
    # ...but sibling sections that do have fields still render.
    assert_includes response.body, "Identity"
    assert_includes response.body, "Everything else"
  end

  test "fields in a multi-column section flow into grid cells, not full rows" do
    get "/admin/kitchen_sinks/new"
    assert_response :success

    # Identity declares no `columns:` → fields span the full row.
    name_wrapper = response.body[/<div[^>]*id="kitchen_sink_name_wrapper"[^>]*>/]
    assert_includes name_wrapper, "col-span-full"

    # Appearance declares `columns: 2` → its fields occupy single grid cells
    # so the two-column grid actually lays out in columns.
    color_wrapper = response.body[/<div[^>]*id="kitchen_sink_favorite_color_wrapper"[^>]*>/]
    refute_includes color_wrapper, "col-span-full"

    # ...but a field with its own `wrapper: {class: "col-span-full"}` keeps it,
    # even inside the multi-column section — field-level col-span always wins.
    website_wrapper = response.body[/<div[^>]*id="kitchen_sink_website_wrapper"[^>]*>/]
    assert_includes website_wrapper, "col-span-full"
  end

  test "a definition without form_layout still renders the single grid" do
    get "/admin/comments/new"
    assert_response :success
    assert_includes response.body, %(name="comment[)
    refute_match(/<details/, response.body)
  end
end
