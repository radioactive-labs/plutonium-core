# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/res/conn/conn_generator"

class ConnGeneratorTest < Rails::Generators::TestCase
  include GeneratorTestHelper

  tests Pu::Res::ConnGenerator
  destination Rails.root

  def setup
    git_restore_dummy_app
    # Create a minimal portal structure for testing
    @portal_dir = destination_root.join("packages/test_portal")
    FileUtils.mkdir_p(@portal_dir.join("config"))
    FileUtils.mkdir_p(@portal_dir.join("app/controllers/test_portal/concerns"))
    FileUtils.mkdir_p(@portal_dir.join("app/policies/test_portal"))
    FileUtils.mkdir_p(@portal_dir.join("app/definitions/test_portal"))

    File.write(@portal_dir.join("config/routes.rb"), <<~RUBY)
      TestPortal::Engine.routes.draw do
        # register resources above.
      end
    RUBY

    File.write(@portal_dir.join("app/controllers/test_portal/concerns/controller.rb"), <<~RUBY)
      module TestPortal
        module Concerns
          module Controller
          end
        end
      end
    RUBY
  end

  def teardown
    FileUtils.rm_rf(@portal_dir) if @portal_dir&.exist?
    # git_restore_dummy_app is called automatically by GeneratorTestHelper
  end

  test "accepts CamelCase destination" do
    run_generator ["User", "--dest=TestPortal"]

    assert_file "packages/test_portal/config/routes.rb" do |content|
      assert_match(/register_resource ::User/, content)
    end
  end

  test "accepts underscore destination" do
    run_generator ["Organization", "--dest=test_portal"]

    assert_file "packages/test_portal/config/routes.rb" do |content|
      assert_match(/register_resource ::Organization/, content)
    end
  end

  test "accepts namespaced resource with slash notation" do
    run_generator ["blogging/post", "--dest=test_portal"]

    assert_file "packages/test_portal/config/routes.rb" do |content|
      assert_match(/register_resource ::Blogging::Post/, content)
    end
  end

  test "accepts namespaced resource with CamelCase notation" do
    run_generator ["Blogging::Tag", "--dest=TestPortal"]

    assert_file "packages/test_portal/config/routes.rb" do |content|
      assert_match(/register_resource ::Blogging::Tag/, content)
    end
  end

  test "fails for resources that do not include Plutonium::Resource::Record" do
    # NonExistentModel doesn't exist so it can't include Plutonium::Resource::Record
    assert_raises(SystemExit) do
      run_generator ["NonExistentModel", "--dest=test_portal"]
    end
  end

  test "creates controller by default" do
    run_generator ["User", "--dest=test_portal"]

    assert_file "packages/test_portal/app/controllers/test_portal/users_controller.rb" do |content|
      assert_match(/class TestPortal::UsersController/, content)
      refute_match(/controller_for/, content)
    end
  end

  test "controller_for option adds an explicit controller_for override" do
    run_generator ["User", "--dest=test_portal", "--controller-for=User"]

    assert_file "packages/test_portal/app/controllers/test_portal/users_controller.rb" do |content|
      assert_match(/controller_for ::User/, content)
    end
  end

  # A gem-provided resource (e.g. Plutonium::Interaction::Async::Run) can have a
  # working policy/definition that subclasses Plutonium::Resource::Policy/Definition
  # directly, not through this host's ::ResourcePolicy/::ResourceDefinition —
  # so the `< ::ResourcePolicy` ancestry check alone would miss it.
  test "expected_parent_policy/definition recognize a base outside ::ResourcePolicy/::ResourceDefinition" do
    generator = Pu::Res::ConnGenerator.new([], {dest: "test_portal"}, destination_root: Rails.root)
    generator.instance_variable_set(:@resource_class, "Plutonium::Interaction::Async::Run")

    assert_equal Plutonium::Interaction::Async::RunPolicy, generator.send(:expected_parent_policy)
    assert_equal Plutonium::Interaction::Async::RunDefinition, generator.send(:expected_parent_definition)
  end

  test "singular option adds singular: true to register_resource" do
    run_generator ["User", "--dest=test_portal", "--singular"]

    assert_file "packages/test_portal/config/routes.rb" do |content|
      assert_match(/register_resource ::User, singular: true/, content)
    end
  end

  # Policy and definition flag tests - verify the generator options exist
  test "policy flag is defined" do
    assert_includes Pu::Res::ConnGenerator.class_options.keys, :policy
  end

  test "definition flag is defined" do
    assert_includes Pu::Res::ConnGenerator.class_options.keys, :definition
  end
end
