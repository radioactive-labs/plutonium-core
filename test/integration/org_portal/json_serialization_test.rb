# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# JSON (RABL) responses must serialize values as JSON-optimized types:
# datetimes as ISO 8601 (not Time#to_s), booleans as true/false, etc.
class OrgPortal::JsonSerializationTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @category = create_category!
    @product = create_product!(category: @category, user: @user, organization: @org,
      status: :active, featured: true, price_cents: 1999,
      metadata: {"brand" => "Acme", "year" => 2025, "tags" => ["a", "b"], "in_stock" => true})
    login_as(@user, portal: :user)
  end

  test "show.json serializes datetimes as ISO 8601 and booleans as true/false" do
    get "/org/#{@org.to_param}/catalog/products/#{@product.id}.json"
    assert_response :success
    body = JSON.parse(response.body)["product"]

    # Datetime: ISO 8601 with T separator and offset, not "YYYY-MM-DD HH:MM:SS UTC"
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})\z/, body["created_at"],
      "created_at should be ISO 8601, got #{body["created_at"].inspect}")
    assert_match(/T/, body["updated_at"])

    # Boolean: real JSON boolean, not a string
    assert_equal true, body["featured"]

    # Enum serializes as its string name
    assert_equal "active", body["status"]

    # JSON (hash) column round-trips as a nested object, not a stringified hash
    assert_equal({"brand" => "Acme", "year" => 2025, "tags" => ["a", "b"], "in_stock" => true},
      body["metadata"])
  end

  test "index.json serializes datetimes as ISO 8601" do
    get "/org/#{@org.to_param}/catalog/products.json"
    assert_response :success
    record = JSON.parse(response.body)["products"].first
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, record["created_at"],
      "created_at should be ISO 8601, got #{record["created_at"].inspect}")
  end
end
