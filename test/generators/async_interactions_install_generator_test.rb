# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/async_interactions/install_generator"

class AsyncInteractionsInstallGeneratorTest < Rails::Generators::TestCase
  include GeneratorTestHelper

  tests Pu::AsyncInteractions::InstallGenerator
  destination Rails.root

  def setup
    git_restore_dummy_app
    @portal_dirs = []
    create_portal!("test_portal")
  end

  def teardown
    @portal_dirs.each { |dir| FileUtils.rm_rf(dir) }
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

  # The generator IS the connect step: there is no separate :connect. An app
  # bootstrapped with --skip-portal, or one that grows a second portal later,
  # re-runs install against the new --dest. Everything already done has to
  # no-op, or the second run duplicates the enable line and the reaper.
  test "a second run against another portal connects it and repeats nothing" do
    create_portal!("second_portal")
    File.write(destination_root.join("config/recurring.yml"), "production:\n")

    run_generator ["--dest=test_portal"]
    run_generator ["--dest=second_portal"]

    %w[test_portal second_portal].each do |portal|
      assert_file "packages/#{portal}/config/routes.rb" do |content|
        assert_equal 1, content.scan("register_resource ::Plutonium::Interaction::Async::Run").size,
          "#{portal} must register the run exactly once"
      end
      assert_file "packages/#{portal}/app/controllers/#{portal}/async_runs_controller.rb"
    end

    # App-wide, so the second portal must not restate them.
    assert_file "config/initializers/plutonium.rb" do |content|
      assert_equal 1, content.scan("config.async_interactions.enabled = true").size
    end
    assert_file "config/recurring.yml" do |content|
      assert_equal 1, content.scan("reap_stalled_async_runs:").size
    end
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
class AsyncInteractionsInstallMainAppGeneratorTest < Rails::Generators::TestCase
  tests Pu::AsyncInteractions::InstallGenerator
  destination File.expand_path("../../tmp/pu_runs_install_main_app", __dir__)
  setup :prepare_destination

  setup do
    FileUtils.mkdir_p(File.join(destination_root, "config/initializers"))
    File.write(File.join(destination_root, "config/routes.rb"), <<~RUBY)
      Rails.application.routes.draw do
        # register resources above.
      end
    RUBY
    # Every real app has one — pu:core:install writes it — and the generator
    # flips config.async_interactions.enabled in it.
    File.write(File.join(destination_root, "config/initializers/plutonium.rb"), <<~RUBY)
      Plutonium.configure do |config|
        # Configure plutonium above.
      end
    RUBY
  end

  test "enables the subsystem" do
    run_generator ["--dest=main_app"]

    # The flag gates the MIGRATION as well as the behaviour, so an install that
    # only wired the portal left the table uncreated and every dispatch raising.
    assert_file "config/initializers/plutonium.rb" do |content|
      assert_match(/config\.async_interactions\.enabled = true/, content)
    end
  end

  test "--skip-portal enables without connecting a portal" do
    run_generator ["--skip-portal"]

    assert_file "config/initializers/plutonium.rb" do |content|
      assert_match(/config\.async_interactions\.enabled = true/, content)
    end
    # A fresh app has no portal worth naming yet; main_app is the wrong home for
    # a run resource in an app about to grow portals.
    assert_no_file "app/controllers/async_runs_controller.rb"
    assert_file "config/routes.rb" do |content|
      refute_match(/register_resource/, content)
    end
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
