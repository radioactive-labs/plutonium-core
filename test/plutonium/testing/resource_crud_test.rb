# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::ResourceCrudTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::ResourceCrud

  resource_tests_for Blogging::Post, portal: :admin

  setup do
    @admin = create_admin!
    @org = create_organization!
    @user = create_user!
    login_as(@admin)
  end

  def create_resource!
    create_post!(user: @user, organization: @org)
  end

  def valid_create_params
    {title: "New", body: "Body", status: :draft, user: @user.to_sgid.to_s, organization: @org.to_sgid.to_s}
  end

  def valid_update_params
    {title: "Updated"}
  end
end

class Plutonium::Testing::ResourceCrudStubsTest < ActiveSupport::TestCase
  test "create_resource! raises NotImplementedError" do
    klass = Class.new do
      include Plutonium::Testing::ResourceCrud
    end
    err = assert_raises(NotImplementedError) { klass.new.create_resource! }
    assert_match(/create_resource!/, err.message)
  end

  test "valid_create_params raises NotImplementedError" do
    klass = Class.new do
      include Plutonium::Testing::ResourceCrud
    end
    assert_raises(NotImplementedError) { klass.new.valid_create_params }
  end
end

class Plutonium::Testing::ResourceCrudSkipTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::ResourceCrud

  resource_tests_for Blogging::Post, portal: :admin,
    actions: %i[index show],
    skip: %i[show]

  setup do
    @admin = create_admin!
    login_as(@admin)
  end

  def create_resource!; create_post!; end
  def valid_create_params; {}; end
  def valid_update_params; {}; end

  test "only generates index test (show is skipped)" do
    methods = self.class.runnable_methods.select { |m| m.start_with?("test_crud") }
    assert_equal ["test_crud:_index"], methods
  end
end
