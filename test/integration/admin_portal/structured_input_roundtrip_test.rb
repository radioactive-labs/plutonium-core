# frozen_string_literal: true

require "test_helper"

class AdminPortal::StructuredInputRoundtripTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  test "edit form repopulates persisted single hash and repeater rows" do
    spec = Catalog::Spec.create!(payload: {"title" => "Saved", "notes" => "Note"}, rows: [{"key" => "k1", "value" => "v1"}])
    get "/admin/catalog/specs/#{spec.id}/edit"
    assert_response :success
    # single fields repopulate
    assert_includes response.body, %(value="Saved")
    assert_includes response.body, %(value="Note")
    # repeater row repopulates (real row, not the NEW_RECORD template)
    assert_includes response.body, %(value="k1")
    assert_includes response.body, %(value="v1")
  end

  test "update persists edited structured values" do
    spec = Catalog::Spec.create!(payload: {"title" => "Old"}, rows: [{"key" => "k1", "value" => "v1"}])
    patch "/admin/catalog/specs/#{spec.id}", params: {catalog_spec: {
      payload: {title: "New", notes: ""},
      rows: {"0" => {key: "k2", value: "v2"}}
    }}
    spec.reload
    assert_equal "New", spec.payload["title"]
    assert_equal [{"key" => "k2", "value" => "v2"}], spec.rows
  end

  test "create persists single hash and cleaned repeater array to json columns" do
    post "/admin/catalog/specs", params: {catalog_spec: {
      payload: {title: "T", notes: "N"},
      rows: {"0" => {key: "a", value: "1"}, "1" => {key: "", value: ""}}
    }}
    spec = Catalog::Spec.order(:id).last
    refute_nil spec, "expected a Catalog::Spec to be created (got redirect #{response.status})"
    assert_equal({"title" => "T", "notes" => "N"}, spec.payload)
    assert_equal([{"key" => "a", "value" => "1"}], spec.rows)
  end

  test "inline-block structured inputs round-trip the same as using:" do
    post "/admin/catalog/specs", params: {catalog_spec: {
      meta: {heading: "H", body: "B"},
      items: {"0" => {label: "first", amount: "10"}, "1" => {label: "", amount: ""}}
    }}
    spec = Catalog::Spec.order(:id).last
    refute_nil spec, "expected a Catalog::Spec to be created (got redirect #{response.status})"
    assert_equal({"heading" => "H", "body" => "B"}, spec.meta)
    assert_equal([{"label" => "first", "amount" => "10"}], spec.items)
  end
end
