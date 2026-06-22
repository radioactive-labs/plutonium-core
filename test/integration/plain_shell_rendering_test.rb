# frozen_string_literal: true

require "test_helper"

class PlainShellRenderingTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @original_shell = Plutonium.configuration.shell
  end

  teardown do
    Plutonium.configuration.shell = @original_shell
  end

  test "plain shell renders rail-less" do
    Plutonium.configuration.shell = :plain
    get "/admin/kitchen_sinks"

    assert_response :success
    # The actual icon rail element carries `data-controller="sidebar icon-rail"`.
    # (A bare "icon-rail" substring also appears in the always-present
    # turbo:before-render listener in Base, so we probe the rail element itself.)
    refute_includes response.body, 'data-controller="sidebar icon-rail"',
      "plain shell should not render the icon rail"
    # The initial pin script reads localStorage directly (no `hasRail &&` guard,
    # which is what distinguishes it from the always-present turbo:before-render
    # listener in Base that also references pu-rail-pinned).
    refute_includes response.body, 'if (localStorage.getItem("pu_rail_pinned") !== "false") {',
      "plain shell should not emit the initial pin script"
    assert_match(/<html[^>]*class="[^"]*pu-no-rail/, response.body,
      "plain shell should mark <html> with pu-no-rail")
  end

  test "modern shell still renders the icon rail and pin script" do
    Plutonium.configuration.shell = :modern
    get "/admin/kitchen_sinks"

    assert_response :success
    assert_includes response.body, 'data-controller="sidebar icon-rail"'
    assert_includes response.body, 'if (localStorage.getItem("pu_rail_pinned") !== "false") {'
    refute_match(/<html[^>]*class="[^"]*pu-no-rail/, response.body)
  end

  test "turbo navigation listener manages pu-no-rail for the modern family" do
    Plutonium.configuration.shell = :modern
    get "/admin/kitchen_sinks"
    assert_response :success
    assert_includes response.body, 'classList.toggle("pu-no-rail"',
      "the turbo:before-render listener should toggle pu-no-rail across navigations"
  end

  test "plain shell also emits the pu-no-rail navigation toggle" do
    Plutonium.configuration.shell = :plain
    get "/admin/kitchen_sinks"
    assert_response :success
    assert_includes response.body, 'classList.toggle("pu-no-rail"'
  end

  test "classic shell still renders its sidebar" do
    Plutonium.configuration.shell = :classic
    get "/admin/kitchen_sinks"

    assert_response :success
    # Regression: the railless work gated the sidebar on rail?, which is false
    # for :classic, so the sidebar stopped rendering while main still reserved
    # the lg:ml-64 offset (empty left gap, no sidebar).
    assert_includes response.body, 'data-controller="sidebar icon-rail"',
      "classic shell should still render its sidebar"
    assert_match(/<main[^>]*class="[^"]*lg:ml-64/, response.body,
      "classic shell should keep its sidebar offset")
  end

  test "engine-level shell makes the whole portal rail-less" do
    AdminPortal::Engine.shell(:plain)
    get "/admin/kitchen_sinks"
    assert_response :success
    refute_includes response.body, 'data-controller="sidebar icon-rail"'
    assert_match(/<html[^>]*class="[^"]*pu-no-rail/, response.body)
  ensure
    AdminPortal::Engine.instance_variable_set(:@shell, nil)
  end
end
