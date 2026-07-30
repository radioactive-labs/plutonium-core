# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# ActionPolicy memoizes the authorization context for the whole request. Our
# scoped entity resolves lazily, and the first authorization of the request is
# the entity's own read? check - which runs while @current_scoped_entity is
# still nil. Without invalidating that memo, `entity_scope: nil` is frozen in
# for the rest of the request, and every `policy_for` / `allowed_to?` that does
# NOT pass an explicit `context:` builds its policy with no tenant.
#
# Callers passing an explicit context (current_policy, current_authorized_scope,
# authorized_resource_scope) were always correct - which is why this stayed
# hidden. The bare callers are the UI ones: SecureAssociation's inline "+",
# table row actions, grid cards.
class OrgPortal::EntityScopeContextTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @category = create_category!
    create_product!(category: @category, user: @user, organization: @org)
    login_as(@user, portal: :user)
  end

  def prefix = "/org/#{@org.to_param}"

  test "the memoized authorization context carries the scoped entity" do
    get "#{prefix}/catalog/products"

    assert_response :success
    assert_equal @org, @controller.send(:authorization_context)[:entity_scope]
  end

  test "policy_for without an explicit context is tenant scoped" do
    get "#{prefix}/catalog/products"

    assert_response :success

    # The SecureAssociation path verbatim: a picker asks about a *different*
    # class than the controller's resource and passes no context:.
    policy = @controller.send(:policy_for, record: Catalog::Category)

    assert_equal @org, policy.entity_scope
  end

  test "the bare policy_for agrees with current_policy on the entity scope" do
    get "#{prefix}/catalog/products"

    assert_response :success
    assert_equal @controller.send(:current_policy).entity_scope,
      @controller.send(:policy_for, record: Catalog::Product).entity_scope
  end

  test "a bare authorized_scope is tenant scoped rather than unscoped" do
    other_org = create_organization!
    other_user = create_user!
    create_membership!(organization: other_org, user: other_user)
    foreign = create_product!(category: @category, user: other_user, organization: other_org)

    get "#{prefix}/catalog/products"
    assert_response :success

    # `authorized_scope` is a helper_method from ActionPolicy, so host app code
    # can reach it without going through authorized_resource_scope. With a nil
    # entity_scope, default_relation_scope falls through to `relation` - i.e.
    # every tenant's records.
    scope = @controller.send(:authorized_scope, Catalog::Product.all)

    refute_includes scope.to_a, foreign
  end

  test "a foreign tenant's entity is still refused" do
    other_org = create_organization!

    get "/org/#{other_org.to_param}/catalog/products"

    # fetch_entity_from_path scopes by `associated_with(current_user)` and then
    # `first!`, so a non-member gets RecordNotFound rather than a redirect.
    assert_response :not_found
  end
end
