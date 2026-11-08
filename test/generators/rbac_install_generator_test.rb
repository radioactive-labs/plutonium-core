# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/rbac/install_generator"

class RbacInstallGeneratorTest < Rails::Generators::TestCase
  include GeneratorTestHelper

  tests Pu::Rbac::InstallGenerator
  destination Rails.root

  def setup
    git_restore_dummy_app
    @portal_dirs = []
    create_portal!("test_portal")
  end

  # The generator edits tracked dummy files (models, policies, initializers),
  # so put them back rather than leaving the last test's output behind.
  def teardown
    @portal_dirs.each { |dir| FileUtils.rm_rf(dir) }
    git_restore_dummy_app
  end

  # A portal is any package whose name ends in _portal or _app
  # (PackageSelector#available_portals), so a bare directory with routes and a
  # Concerns::Controller is enough for --dest to resolve without prompting.
  def create_portal!(name)
    dir = destination_root.join("packages/#{name}")
    @portal_dirs << dir
    FileUtils.mkdir_p(dir.join("config"))
    FileUtils.mkdir_p(dir.join("app/controllers/#{name}/concerns"))

    File.write(dir.join("config/routes.rb"), <<~ROUTES)
      #{name.camelize}::Engine.routes.draw do
        # register resources above.
      end
    ROUTES

    File.write(dir.join("app/controllers/#{name}/concerns/controller.rb"), <<~CONTROLLER)
      module #{name.camelize}
        module Concerns
          module Controller
          end
        end
      end
    CONTROLLER

    dir
  end

  test "enables rbac and writes the initializer" do
    run_generator %w[--holders=OrganizationUser:organization --skip-portal]

    assert_file "config/initializers/plutonium.rb" do |content|
      assert_equal 1, content.scan("config.rbac.enabled = true").size
    end
    assert_file "config/initializers/rbac.rb" do |content|
      refute_match(/config\.rbac\.holder/, content)
      assert_match(/system_role :owner/, content)
      assert_match(/system_role :member/, content)
    end
  end

  test "defines rbac_holder on ResourcePolicy for a membership holder" do
    run_generator %w[--holders=OrganizationUser:organization --skip-portal]

    assert_file "app/policies/resource_policy.rb",
      /  def rbac_holder\n    OrganizationUser\.find_by\(user:, organization: entity_scope\) if entity_scope\n  end\nend\n\z/
  end

  test "resolves the user itself outside a tenant when a plain holder is given" do
    run_generator %w[--holders=OrganizationUser:organization User --skip-portal]

    assert_file "app/policies/resource_policy.rb",
      /  def rbac_holder\n    return user unless entity_scope\n\n    OrganizationUser\.find_by\(user:, organization: entity_scope\)\n  end\n/
    assert_file "app/models/user.rb", /include Plutonium::Rbac::Holder/
  end

  test "a user holder of another class holds roles everywhere" do
    run_generator %w[--holders=OrganizationUser:organization Admin --skip-portal]

    assert_file "app/policies/resource_policy.rb",
      /  def rbac_holder\n    return user if user\.is_a\?\(Admin\)\n    OrganizationUser\.find_by\(user:, organization: entity_scope\) if entity_scope\n  end\n/
  end

  test "a lone user holder is the user" do
    run_generator %w[--holders=User --skip-portal]

    assert_file "app/policies/resource_policy.rb", /  def rbac_holder\n    user\n  end\n/
  end

  test "uses the --user-association key" do
    run_generator %w[--holders=OrganizationUser:organization --user-association=member --skip-portal]

    assert_file "app/policies/resource_policy.rb",
      /OrganizationUser\.find_by\(member: user, organization: entity_scope\) if entity_scope/
  end

  test "writes rbac_holder to ResourcePolicy even when --policy names another class" do
    File.write(destination_root.join("app/policies/other_policy.rb"), "class OtherPolicy < ResourcePolicy\nend\n")

    run_generator %w[--holders=OrganizationUser:organization --policy=OtherPolicy --skip-portal]

    assert_file "app/policies/other_policy.rb" do |content|
      assert_match(/include Plutonium::Rbac::Policy/, content)
      refute_match(/rbac_holder/, content)
    end
    assert_file "app/policies/resource_policy.rb" do |content|
      refute_match(/include Plutonium::Rbac::Policy/, content)
      assert_match(/def rbac_holder/, content)
    end
  end

  test "wires holder models and the policy" do
    run_generator %w[--holders=OrganizationUser:organization --skip-portal]

    assert_file "app/models/organization_user.rb" do |content|
      assert_match(/^class OrganizationUser < ::ResourceRecord\n  include Plutonium::Rbac::Holder\n/, content)
      assert_match(/def rbac_entity = organization\n\n\s*# add methods above\./, content)
    end
    assert_file "app/policies/resource_policy.rb",
      /^class ResourcePolicy < Plutonium::Resource::Policy\n  include Plutonium::Rbac::Policy\n/
  end

  test "removes the always-true create? and read? from the policy" do
    assert_file "app/policies/resource_policy.rb", /def create\?\n    true\n  end/

    output = run_generator %w[--holders=OrganizationUser:organization --skip-portal]

    assert_file "app/policies/resource_policy.rb" do |content|
      assert_equal <<~RUBY, content
        class ResourcePolicy < Plutonium::Resource::Policy
          include Plutonium::Rbac::Policy

          # Who holds roles for `user` in `entity_scope`. nil means no permissions.
          def rbac_holder
            OrganizationUser.find_by(user:, organization: entity_scope) if entity_scope
          end
        end
      RUBY
    end
    assert_match(/remove\s+create\? from app\/policies\/resource_policy\.rb/, output)
    assert_match(/remove\s+read\? from app\/policies\/resource_policy\.rb/, output)
  end

  test "removes the one-line form too" do
    File.write(destination_root.join("app/policies/resource_policy.rb"), <<~RUBY)
      class ResourcePolicy < Plutonium::Resource::Policy
        def create? = true

        def read? = true
      end
    RUBY

    run_generator %w[--holders=OrganizationUser:organization --skip-portal]

    assert_file "app/policies/resource_policy.rb" do |content|
      refute_match(/def (create|read)\?/, content)
    end
  end

  test "leaves a custom create? alone and warns about it" do
    File.write(destination_root.join("app/policies/resource_policy.rb"), <<~RUBY)
      class ResourcePolicy < Plutonium::Resource::Policy
        def create?
          user.admin?
        end

        def read?
          true
        end
      end
    RUBY

    output = run_generator %w[--holders=OrganizationUser:organization --skip-portal]

    assert_file "app/policies/resource_policy.rb" do |content|
      assert_match(/  def create\?\n    user\.admin\?\n  end\n/, content)
      refute_match(/def read\?/, content)
    end
    assert_match(/warn\s+app\/policies\/resource_policy\.rb still defines create\?/, output)
    refute_match(/still defines read\?/, output)
  end

  test "connects the role resource to a portal" do
    run_generator %w[--holders=OrganizationUser:organization --dest=test_portal]

    assert_file "packages/test_portal/app/controllers/test_portal/rbac_roles_controller.rb" do |content|
      assert_match(/class TestPortal::RbacRolesController < ::TestPortal::ResourceController/, content)
      assert_match(/controller_for ::Plutonium::Rbac::Role/, content)
      assert_match(/include TestPortal::Concerns::Controller/, content)
      assert_match(/super\.merge\(entity: current_scoped_entity\)/, content)
    end
    assert_file "packages/test_portal/config/routes.rb" do |content|
      assert_equal 1, content.scan("register_resource ::Plutonium::Rbac::Role").size
    end
  end

  test "a second run repeats nothing" do
    run_generator %w[--holders=OrganizationUser:organization --dest=test_portal]
    run_generator %w[--holders=OrganizationUser:organization --dest=test_portal]

    assert_file "config/initializers/plutonium.rb" do |content|
      assert_equal 1, content.scan("config.rbac.enabled = true").size
    end
    assert_file "app/models/organization_user.rb" do |content|
      assert_equal 1, content.scan("include Plutonium::Rbac::Holder").size
      assert_equal 1, content.scan("def rbac_entity").size
    end
    assert_file "app/policies/resource_policy.rb" do |content|
      assert_equal 1, content.scan("include Plutonium::Rbac::Policy").size
      assert_equal 1, content.scan("def rbac_holder").size
    end
    assert_file "packages/test_portal/config/routes.rb" do |content|
      assert_equal 1, content.scan("register_resource ::Plutonium::Rbac::Role").size
    end
  end

  test "--skip-portal connects nothing" do
    run_generator %w[--holders=OrganizationUser:organization --skip-portal]

    assert_no_file "packages/test_portal/app/controllers/test_portal/rbac_roles_controller.rb"
    assert_file "packages/test_portal/config/routes.rb" do |content|
      refute_match(/register_resource/, content)
    end
  end
end
