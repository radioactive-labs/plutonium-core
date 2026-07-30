# frozen_string_literal: true

require "test_helper"

# Each portal authenticates through its own Rodauth configuration, so a person must
# be able to hold a session in several portals at once.
#
# Rodauth resets the session on every login (and on the `remember` feature's
# `load_memory` autologin) to defend against session fixation, and rodauth-rails
# implements that as a full `reset_session`. The `session_isolation` feature narrows
# that to the configuration doing the login - see
# lib/rodauth/features/session_isolation.rb.
class MultiPortalSessionTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  test "signing into the user portal does not evict the admin session" do
    admin = create_admin!
    user = create_user!

    post "/admins/login", params: {email: admin.email, password: "password123"}
    follow_redirect!
    get "/admin"
    assert_response :success, "admin should be signed in"

    post "/users/login", params: {email: user.email, password: "password123"}
    follow_redirect!

    get "/locus"
    assert_response :success, "user should be signed in"

    get "/admin"
    assert_response :success, "admin should still be signed in after the user signs in"
  end

  test "signing into the admin portal does not evict the user session" do
    admin = create_admin!
    user = create_user!

    post "/users/login", params: {email: user.email, password: "password123"}
    follow_redirect!
    get "/locus"
    assert_response :success, "user should be signed in"

    post "/admins/login", params: {email: admin.email, password: "password123"}
    follow_redirect!

    get "/admin"
    assert_response :success, "admin should be signed in"

    get "/locus"
    assert_response :success, "user should still be signed in after the admin signs in"
  end

  # The `remember` feature autologins every configuration on every request via
  # `RodauthApp#route`. Before session_isolation, that autologin reset the session
  # and evicted whichever portal had just been used, so the last `load_memory` call
  # in the route block won permanently.
  test "remember autologin does not steal the session from the other portal" do
    admin = create_admin!
    user = create_user!

    # `remember` must be opted into, otherwise no remember cookie is issued and this
    # test would not exercise load_memory at all.
    post "/admins/login", params: {email: admin.email, password: "password123", remember: "remember"}
    post "/users/login", params: {email: user.email, password: "password123", remember: "remember"}
    assert_includes cookies.to_hash.keys, "_admin_remember"
    assert_includes cookies.to_hash.keys, "_user_remember"

    3.times do
      get "/locus"
      assert_response :success, "user session should survive the admin's remember autologin"
      get "/admin"
      assert_response :success, "admin session should survive the user's remember autologin"
    end
  end

  test "signing out of one portal leaves the other signed in" do
    admin = create_admin!
    user = create_user!

    post "/admins/login", params: {email: admin.email, password: "password123"}
    post "/users/login", params: {email: user.email, password: "password123"}

    post "/users/logout"

    get "/locus"
    assert_response :redirect, "user should be signed out"

    get "/admin"
    assert_response :success, "admin should still be signed in"
  end

  test "each configuration namespaces its session keys" do
    admin = create_admin!
    user = create_user!

    post "/admins/login", params: {email: admin.email, password: "password123"}
    post "/users/login", params: {email: user.email, password: "password123"}

    keys = session.to_hash.keys
    assert_includes keys, "user_account_id"
    assert_includes keys, "admin_account_id"

    # Every key belongs to exactly one configuration, so the two configurations
    # cannot read or clobber each other's state.
    assert_includes keys, "user_authenticated_by"
    assert_includes keys, "admin_authenticated_by"
    refute_includes keys, "authenticated_by"
  end

  # A config's session keys MUST all rotate together. An explicitly configured
  # `session_key` is NOT prefixed, so setting one alongside `session_key_prefix`
  # leaves the account id on a different name from every other key. On upgrade that
  # yields a session holding an account id but no `authenticated_by`, and Rodauth
  # 500s on every request: `logged_in_via_remember_key?` calls `nil.include?`.
  #
  # session_isolation also decides key ownership by prefix, so a config without one
  # gets nothing carried for it.
  test "each configuration's account id key carries its own session_key_prefix" do
    get "/storefront"

    {user: "user_", admin: "admin_"}.each do |name, prefix|
      rodauth = request.env["rodauth.#{name}"]

      assert_equal prefix, rodauth.session_key_prefix,
        "#{name} config must set session_key_prefix for session_isolation to own its keys"
      assert rodauth.session_key.to_s.start_with?(prefix),
        "#{name} config session_key #{rodauth.session_key.inspect} is missing the " \
        "#{prefix.inspect} prefix - it must rotate together with every other key"
    end
  end

  # Ownership must be derived from `session_key_prefix`, NOT by calling every method
  # matching /_session_key\z/. That name is not reserved for readers: the
  # `single_session` feature exposes `reset_single_session_key` and
  # `update_single_session_key` as public auth methods that UPDATE the database with a
  # fresh random key - calling them would sign the sibling out, the exact opposite of
  # what this feature is for. `jwt_session_key` returns nil, which would land as "".
  test "sibling keys are matched by prefix, not by enumerating reader methods" do
    get "/storefront"
    rodauth = request.env["rodauth.user"]

    # A prefixed key no Rodauth reader is named after - method enumeration would miss
    # it, prefix matching carries it.
    rodauth.session["admin_key_from_a_feature_we_never_enumerated"] = "carry me"
    # Ours, and nobody's: neither may be carried.
    rodauth.session["user_authenticated_by"] = ["password"]
    rodauth.session["plutonium_wizards"] = {"x" => "y"}

    carried = rodauth.send(:sibling_session_data)

    assert_equal({"admin_key_from_a_feature_we_never_enumerated" => "carry me"}, carried)
  end

  # A sibling with no prefix uses Rodauth's unprefixed default key names - the same
  # names we would use without a prefix. Carrying them could restore our own pre-login
  # auth state across the reset and defeat the session fixation protection.
  test "nothing is carried for a sibling that has no session_key_prefix" do
    get "/storefront"
    rodauth = request.env["rodauth.user"]
    sibling = request.env["rodauth.admin"]

    rodauth.session["admin_authenticated_by"] = ["password"]

    # Safe to poke: the rodauth instance is per-request and discarded after this test.
    sibling.define_singleton_method(:session_key_prefix) { nil }

    assert_empty rodauth.send(:sibling_session_data)
  end

  test "session id still rotates on login, so session fixation is defeated" do
    admin = create_admin!
    user = create_user!

    # Establish a session (and a session id) before the login under test.
    post "/admins/login", params: {email: admin.email, password: "password123"}
    before = request.session_options[:id].to_s
    refute_empty before

    post "/users/login", params: {email: user.email, password: "password123"}
    after = request.session_options[:id].to_s

    refute_empty after
    refute_equal before, after, "session id must rotate across login"
  end

  # Only the sibling configurations' auth state is carried across the reset.
  # Application session data stays pre-auth-plantable, so it must keep being
  # dropped on login exactly as it was before session_isolation.
  test "application session data is still cleared on login" do
    admin = create_admin!
    user = create_user!
    org = create_organization!
    OrganizationUser.create!(organization: org, user: user, role: :owner)

    post "/users/login", params: {email: user.email, password: "password123"}
    get "/org/#{org.to_param}"
    assert_response :success
    assert_includes session.to_hash.keys, "org_portal__scoped_entity_id",
      "visiting the org portal should remember the scoped entity"

    post "/admins/login", params: {email: admin.email, password: "password123"}

    refute_includes session.to_hash.keys, "org_portal__scoped_entity_id",
      "application session data should not survive a login"
    assert_includes session.to_hash.keys, "user_account_id",
      "the user's auth state should survive the admin login"
  end
end
