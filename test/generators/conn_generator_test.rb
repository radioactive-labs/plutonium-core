# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/res/conn/conn_generator"

class ConnGeneratorTest < Rails::Generators::TestCase
  tests Pu::Res::ConnGenerator
  destination Rails.root

  def setup
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
    FileUtils.rm_rf(@portal_dir)
  end

  test "accepts CamelCase destination" do
    run_generator ["Post", "--dest=TestPortal"]

    assert_file "packages/test_portal/config/routes.rb" do |content|
      assert_match(/register_resource ::Post/, content)
    end
  end

  test "accepts underscore destination" do
    run_generator ["Comment", "--dest=test_portal"]

    assert_file "packages/test_portal/config/routes.rb" do |content|
      assert_match(/register_resource ::Comment/, content)
    end
  end

  test "accepts namespaced resource with slash notation" do
    run_generator ["blogging/post", "--dest=test_portal"]

    assert_file "packages/test_portal/config/routes.rb" do |content|
      assert_match(/register_resource ::Blogging::Post/, content)
    end
  end

  test "accepts namespaced resource with CamelCase notation" do
    run_generator ["Blogging::Comment", "--dest=TestPortal"]

    assert_file "packages/test_portal/config/routes.rb" do |content|
      assert_match(/register_resource ::Blogging::Comment/, content)
    end
  end

  test "fails for resources that do not include Plutonium::Resource::Record" do
    # SolidQueue::Pause is an ActiveRecord model but not a Plutonium resource
    assert_raises(SystemExit) do
      run_generator ["SolidQueue::Pause", "--dest=test_portal"]
    end
  end
end
