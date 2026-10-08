# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Regression: under `:path` entity scoping every route name carries the
# `<param_key>_` prefix, so the typeahead helper is
# `typeahead_input_organization_scoped_catalog_products_path`. Looking up the
# unprefixed name found nothing, the select got no typeahead URL, and it fell
# back to filtering only its first `choice_limit` preloaded options.
class OrgPortal::TypeaheadUrlTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    login_as(@user, portal: :user)
  end

  def prefix = "/org/#{@org.to_param}"

  test "association select gets the entity-scoped typeahead url" do
    get "#{prefix}/catalog/products/new"

    assert_response :success
    assert_select "select[data-slim-select-typeahead-url-value='#{prefix}/catalog/products/typeahead/input/category']"
  end

  test "entity-scoped typeahead url answers with matching records" do
    # Categories are tenant-scoped through their products.
    create_product!(category: create_category!(name: "Gardening"), user: @user, organization: @org)

    get "#{prefix}/catalog/products/typeahead/input/category", params: {q: "garden"}, as: :json

    assert_response :success
    assert_includes response.body, "Gardening"
  end
end
