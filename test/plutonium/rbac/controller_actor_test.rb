# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class Plutonium::Rbac::ControllerActorTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    login_as(@user, portal: :user)
  end

  # Current is reset after the request completes, so record the value as the
  # controller installs it.
  def capture_installed_resolver
    seen = nil
    original = Plutonium::Rbac::Current.method(:actor_resolver=)
    Plutonium::Rbac::Current.singleton_class.define_method(:actor_resolver=) do |value|
      seen = value
      original.call(value)
    end
    yield
    seen
  ensure
    Plutonium::Rbac::Current.singleton_class.remove_method(:actor_resolver=) if Plutonium::Rbac::Current.singleton_class.method_defined?(:actor_resolver=, false)
  end

  test "a portal request installs the actor resolver" do
    seen = capture_installed_resolver { get "/org/#{@org.to_param}/async_runs" }
    assert_response :success
    assert_kind_of Proc, seen
  end

  test "a portal request records its portal, so the portal's rbac_holder applies" do
    seen = nil
    original = Plutonium::Rbac::Current.method(:portal=)
    Plutonium::Rbac::Current.singleton_class.define_method(:portal=) do |value|
      seen = value
      original.call(value)
    end
    get "/org/#{@org.to_param}/async_runs"
    assert_response :success
    assert_equal OrgPortal, seen
  ensure
    Plutonium::Rbac::Current.singleton_class.remove_method(:portal=)
  end

  test "nothing is installed when RBAC is disabled" do
    Plutonium.configuration.rbac.enabled = false
    seen = capture_installed_resolver { get "/org/#{@org.to_param}/async_runs" }
    assert_nil seen
  ensure
    Plutonium.configuration.rbac.enabled = true
  end
end
