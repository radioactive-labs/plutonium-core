# frozen_string_literal: true

require "test_helper"

class Plutonium::Rbac::PolicyAttributeFilterTest < ActiveSupport::TestCase
  class FieldPolicy < Plutonium::Resource::Policy
    include Plutonium::Rbac::Policy
    rbac_restricted_attributes :body

    def permitted_attributes_for_read = %i[title body]

    def permitted_attributes_for_create = %i[title body]
  end

  class IndexOverridePolicy < FieldPolicy
    def permitted_attributes_for_index = %i[title body status]
  end

  teardown { Plutonium::Rbac::Current.reset }

  def policy(klass = FieldPolicy)
    klass.new(Blogging::Post.new, user: User.new, entity_scope: nil)
  end

  def with_keys(*keys)
    Plutonium::Rbac::Current.permission_override = keys.to_set
    yield
  ensure
    Plutonium::Rbac::Current.permission_override = nil
  end

  test "read side hides restricted field without read grant" do
    with_keys do
      assert_equal %i[title], policy.permitted_attributes_for_read
      assert_equal %i[title], policy.permitted_attributes_for_show
      assert_equal %i[title], policy.permitted_attributes_for_export
    end
    with_keys("blogging/post.body.read") { assert_equal %i[title body], policy.permitted_attributes_for_show }
  end

  test "write side needs write grant" do
    with_keys("blogging/post.body.read") { assert_equal %i[title], policy.permitted_attributes_for_edit }
    with_keys("blogging/post.body.write") { assert_equal %i[title body], policy.permitted_attributes_for_new }
  end

  test "subclass overrides are filtered too" do
    with_keys { assert_equal %i[title status], policy(IndexOverridePolicy).permitted_attributes_for_index }
  end
end
