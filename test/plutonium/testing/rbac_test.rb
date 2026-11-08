# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::RbacTest < ActiveSupport::TestCase
  include Plutonium::Testing::Rbac

  test "overrides and restores" do
    with_rbac_permissions("blogging/post.read") do
      assert_equal Set["blogging/post.read"], Plutonium::Rbac::Current.permission_keys_for(nil)
    end
    assert_nil Plutonium::Rbac::Current.permission_override
  end

  test "restores on exception" do
    assert_raises(RuntimeError) { with_rbac_permissions("x.read") { raise "boom" } }
    assert_nil Plutonium::Rbac::Current.permission_override
  end
end
