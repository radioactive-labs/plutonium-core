# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/async_interactions/install_generator"

class RunsInstallGeneratorTest < Rails::Generators::TestCase
  include GeneratorTestHelper

  tests Pu::AsyncInteractions::InstallGenerator
  destination Rails.root

  def setup
    git_restore_dummy_app
    @portal_dir = destination_root.join("packages/test_portal")
    FileUtils.mkdir_p(@portal_dir.join("config"))
    FileUtils.mkdir_p(@portal_dir.join("app/controllers/test_portal/concerns"))

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
  end

  test "registers Plutonium::Interaction::Async::Run and generates a controller with controller_for" do
    run_generator ["--dest=test_portal"]

    assert_file "packages/test_portal/config/routes.rb" do |content|
      assert_match(/register_resource ::Plutonium::Interaction::Async::Run$/, content)
    end

    assert_file "packages/test_portal/app/controllers/test_portal/async_runs_controller.rb" do |content|
      assert_match(/class TestPortal::AsyncRunsController/, content)
      assert_match(/controller_for ::Plutonium::Interaction::Async::Run/, content)
    end
  end

  test "is idempotent on the route registration" do
    run_generator ["--dest=test_portal"]
    run_generator ["--dest=test_portal"]

    assert_file "packages/test_portal/config/routes.rb" do |content|
      assert_equal 1, content.scan("register_resource ::Plutonium::Interaction::Async::Run").size
    end
  end

  # The dummy app has solid_queue in its Gemfile (see test/dummy/Gemfile),
  # matching what gem_in_bundle?("solid_queue") checks against.
  test "schedules ReapJob in config/recurring.yml when solid_queue is present" do
    File.write(destination_root.join("config/recurring.yml"), "production:\n")

    run_generator ["--dest=test_portal"]

    assert_file "config/recurring.yml" do |content|
      assert_match(/reap_stalled_async_runs:/, content)
      assert_match(/class: Plutonium::Interaction::Async::ReapJob/, content)
      assert_match(/schedule: "every 15 minutes"/, content)
    end
  end

  test "is idempotent on the recurring task" do
    File.write(destination_root.join("config/recurring.yml"), "production:\n")

    run_generator ["--dest=test_portal"]
    run_generator ["--dest=test_portal"]

    assert_file "config/recurring.yml" do |content|
      assert_equal 1, content.scan("reap_stalled_async_runs:").size
    end
  end

  test "does not raise when config/recurring.yml is missing" do
    FileUtils.rm_f(destination_root.join("config/recurring.yml"))

    run_generator ["--dest=test_portal"]

    assert_no_file "config/recurring.yml"
  end
end

# main_app is a valid --dest (see PackageSelector#available_portals) and has
# neither a packages/ tree nor a Concerns::Controller to include.
#
# Runs against a throwaway destination_root rather than test/dummy: unlike the
# portal cases above, which only add untracked files, this one writes the main
# app's own config/routes.rb — a TRACKED file every other test in the suite
# shares. available_portals always offers "main_app" regardless of
# destination_root (it reads Rails.root), so --dest=main_app still resolves.
class RunsInstallMainAppGeneratorTest < Rails::Generators::TestCase
  tests Pu::AsyncInteractions::InstallGenerator
  destination File.expand_path("../../tmp/pu_runs_install_main_app", __dir__)
  setup :prepare_destination

  setup do
    FileUtils.mkdir_p(File.join(destination_root, "config"))
    File.write(File.join(destination_root, "config/routes.rb"), <<~RUBY)
      Rails.application.routes.draw do
        # register resources above.
      end
    RUBY
  end

  test "supports --dest=main_app" do
    run_generator ["--dest=main_app"]

    assert_file "config/routes.rb" do |content|
      assert_match(/register_resource ::Plutonium::Interaction::Async::Run$/, content)
    end

    assert_file "app/controllers/async_runs_controller.rb" do |content|
      assert_match(/class AsyncRunsController < ::ResourceController/, content)
      assert_match(/controller_for ::Plutonium::Interaction::Async::Run/, content)
      refute_match(/Concerns::Controller/, content)
    end

    assert_no_file "packages/main_app/app/controllers/main_app/async_runs_controller.rb"
  end
end
