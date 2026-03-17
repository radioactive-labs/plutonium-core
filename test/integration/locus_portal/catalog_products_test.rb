# frozen_string_literal: true

require "test_helper"

class LocusPortal::CatalogProductsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include SharedTests::CatalogProductTests

  setup do
    @org = create_organization!
    @user = create_user!
    @membership = create_membership!(organization: @org, user: @user)
    login_as_user(@user)
  end

  def path_prefix
    "/locus"
  end
end
