# frozen_string_literal: true

require "test_helper"

class AdminPortal::StructuredInputRoundtripTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
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
end
