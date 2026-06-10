# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Regression: a resource form input with `condition:` whose `choices:` lambda
# depends on a sibling attr_accessor virtual attribute must not nullify the
# submitted value during param extraction.
#
# `attr_accessor` fields are absent from `attribute_names`, so the initial
# safe_keys slice in submitted_resource_params skips them. The extraction
# instance therefore has nil for the virtual attribute, the condition evaluates
# to false, and AcceptsChoices validates against an empty choices list,
# nullifying a valid submitted value.
class OrgPortal::VirtualAttrConditionedSelectTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @category = create_category!
    # Seed a product so the category appears in the associated_with_organization scope
    # (categories are scoped via joins(:products).where(organization_id: org.id))
    create_product!(category: @category, user: @user, organization: @org)
    login_as(@user, portal: :user)
  end

  def prefix = "/org/#{@org.to_param}"

  test "POST create with attr_accessor sibling does not nullify the conditioned select value" do
    post "#{prefix}/catalog/products",
      params: {
        catalog_product: {
          name: "Tier Test",
          tier: "pro",
          status: "active",
          category: @category.to_sgid.to_s,
          user: @user.to_sgid.to_s,
          organization: @org.to_sgid.to_s,
          price_cents: 1999
        }
      }

    assert_response :redirect
    assert_equal "active", Catalog::Product.last.status
  end

end
