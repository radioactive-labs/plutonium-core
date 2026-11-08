# frozen_string_literal: true

require "test_helper"

class Plutonium::Rbac::PolicyTest < ActiveSupport::TestCase
  include IntegrationTestHelper
  include RbacHelpers

  class RbacPostPolicy < Plutonium::Resource::Policy
    include Plutonium::Rbac::Policy

    def self.name = "Blogging::PostPolicy" # resource inference by name
  end

  class GatedPostPolicy < RbacPostPolicy
    def publish? = super && record.draft?
  end

  setup do
    Plutonium::Rbac::Current.reset
    Plutonium::Rbac::Catalog.reset!
    stub_rbac_holder { user }
    @user = create_user!
    @post = Blogging::Post.new(title: "t", body: "b", status: :draft)
  end

  teardown do
    Plutonium::Rbac::Current.reset
  end

  def policy(klass = RbacPostPolicy, record: @post)
    klass.new(record, user: @user, entity_scope: nil)
  end

  def with_keys(*keys, &)
    Plutonium::Rbac::Current.permission_override = keys.to_set
    yield
  ensure
    Plutonium::Rbac::Current.permission_override = nil
  end

  test "core predicates map to permissions" do
    with_keys("blogging/post.read", "blogging/post.update") do
      assert policy.read?
      assert policy.update?
      refute policy.create?
      refute policy.destroy?
      refute policy.export_csv?
    end
  end

  test "derived rules still delegate" do
    with_keys("blogging/post.update") do
      assert policy.edit?
      assert policy.kanban_move?
      refute policy.new?
    end
    with_keys("blogging/post.read") { assert policy(record: Blogging::Post).index? }
  end

  test "custom action resolves from the definition" do
    assert policy.respond_to?(:publish?)
    with_keys("blogging/post.publish") { assert policy.allowed_to?(:publish?) }
    with_keys { refute policy.allowed_to?(:publish?) }
  end

  test "explicit override combines with super" do
    with_keys("blogging/post.publish") do
      assert policy(GatedPostPolicy).publish?
      @post.status = :published
      refute policy(GatedPostPolicy).publish?
    end
  end

  test "unknown predicates still raise through send_with_report" do
    refute policy.respond_to?(:frobnicate?)
    assert_raises(NotImplementedError) { policy.send_with_report(:frobnicate?) }
  end

  test "hand-declared keys" do
    with_keys("reports.view") { assert policy.granted?("reports.view") }
  end

  test "nil holder denies" do
    stub_rbac_holder { nil }
    refute policy.read?
  end

  test "the policy reads the holder from ResourcePolicy#rbac_holder" do
    stub_rbac_holder { [:holder, user, entity_scope] }
    assert_equal [:holder, @user, nil], policy.current_rbac_holder
  end

  test "resource_class_for infers through portal namespaces" do
    assert_equal Blogging::Post, Plutonium::Rbac::Policy.resource_class_for(Blogging::PostPolicy)
    assert_equal Blogging::Post, Plutonium::Rbac::Policy.resource_class_for(OrgPortal::Blogging::PostPolicy)
  end

  test "holder resolves once per user and tenant across policy instances" do
    calls = 0
    stub_rbac_holder do
      calls += 1
      nil
    end
    10.times { refute policy.read? }
    assert_equal 1, calls
  end

  test "a permission override skips holder resolution" do
    stub_rbac_holder { raise "resolved" }
    with_keys("blogging/post.read") { assert policy.read? }
  end
end
