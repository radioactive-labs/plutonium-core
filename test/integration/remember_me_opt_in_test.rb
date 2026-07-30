# frozen_string_literal: true

require "test_helper"

# "Remember me" is opt-in: the login form renders a checkbox, and the configs use
# `after_login { remember_login if param_or_nil(remember_param) == remember_remember_param_value }`.
# Logging in without ticking it must not issue a 14-day persistent cookie.
#
# The comparison is against the value, not just presence: `remember_param` is shared
# with Rodauth's /remember settings page, which also submits `forget` and `disable`,
# so a bare truthiness check would let `remember=disable` remember you.
class RememberMeOptInTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  test "login form renders a remember me checkbox" do
    get "/users/login"
    assert_response :success

    assert_select "input[type=checkbox][name=remember]", 1
    assert_select "label[for=remember]"
  end

  # Rails' check_box helper emits a hidden "0" field by default, so an unticked box
  # still submits `remember=0`. The value comparison in after_login already rejects
  # that, so this is defence in depth: it keeps a junk param off the wire, and keeps
  # the form correct for a config that only checks presence.
  test "remember checkbox does not emit a hidden fallback field" do
    get "/users/login"

    assert_select "input[type=hidden][name=remember]", 0
  end

  test "logging in without ticking remember issues no remember cookie" do
    user = create_user!

    post "/users/login", params: {email: user.email, password: "password123"}

    refute_includes cookies.to_hash.keys, "_user_remember"
  end

  test "logging in with remember ticked issues a remember cookie" do
    user = create_user!

    post "/users/login", params: {email: user.email, password: "password123", remember: "remember"}

    assert_includes cookies.to_hash.keys, "_user_remember"
  end

  # Without a remember cookie there is nothing for load_memory to restore, so the
  # login must not survive losing the session cookie.
  test "an unremembered login does not survive session loss" do
    user = create_user!

    post "/users/login", params: {email: user.email, password: "password123"}
    get "/locus"
    assert_response :success

    cookies.delete("_dummy_session")
    get "/locus"
    assert_response :redirect, "an unremembered user should be signed out"
  end

  test "a remembered login survives session loss" do
    user = create_user!

    post "/users/login", params: {email: user.email, password: "password123", remember: "remember"}

    cookies.delete("_dummy_session")
    get "/locus"
    assert_response :success, "a remembered user should be signed back in by load_memory"
  end

  # The admin config uses `use_multi_phase_login?`, so the password lands on a
  # second form. The checkbox has to be on that phase, since it is the one that
  # triggers after_login.
  test "multi-phase login shows the checkbox on the password phase" do
    admin = create_admin!

    post "/admins/login", params: {email: admin.email}
    assert_response :success

    assert_select "input[type=password][name=password]", 1
    assert_select "input[type=checkbox][name=remember]", 1
  end
end
