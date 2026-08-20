# frozen_string_literal: true

require "test_helper"
require "rails/generators/test_case"
require "generators/pu/wizards/install_generator"

# App-wide, and takes no portal — a wizard mounts itself wherever it is declared,
# so unlike the run resource there is nothing here to route into a portal.
#
# Runs against a throwaway destination_root rather than test/dummy, because it
# writes config/initializers/plutonium.rb and config/recurring.yml — tracked
# files the rest of the suite shares.
class WizardsInstallGeneratorTest < Rails::Generators::TestCase
  tests Pu::Wizards::InstallGenerator
  destination File.expand_path("../../tmp/pu_wizards_install", __dir__)
  setup :prepare_destination

  setup do
    FileUtils.mkdir_p(File.join(destination_root, "config/initializers"))
    File.write(File.join(destination_root, "config/initializers/plutonium.rb"), <<~RUBY)
      Plutonium.configure do |config|
        # Configure plutonium above.
      end
    RUBY
  end

  test "enables the subsystem" do
    run_generator

    # The flag gates the MIGRATION as well as the behaviour: while it is off the
    # wizard migration path is never registered, so plutonium_wizard_sessions
    # does not exist and nothing works.
    assert_file "config/initializers/plutonium.rb" do |content|
      assert_match(/config\.wizards\.enabled = true/, content)
    end
  end

  test "schedules the sweep when solid_queue is in the bundle" do
    File.write(File.join(destination_root, "Gemfile"), %(gem "solid_queue"\n))
    File.write(File.join(destination_root, "config/recurring.yml"), "production:\n")

    run_generator

    assert_file "config/recurring.yml" do |content|
      assert_match(/sweep_abandoned_wizards:/, content)
      assert_match(/class: Plutonium::Wizard::SweepJob/, content)
      assert_match(/schedule: "every 15 minutes"/, content)
    end
  end

  test "--schedule overrides the cadence" do
    File.write(File.join(destination_root, "Gemfile"), %(gem "solid_queue"\n))
    File.write(File.join(destination_root, "config/recurring.yml"), "production:\n")

    run_generator ["--schedule=every hour"]

    assert_file "config/recurring.yml" do |content|
      assert_match(/schedule: "every hour"/, content)
    end
  end

  test "is idempotent — a second run does not duplicate the task" do
    File.write(File.join(destination_root, "Gemfile"), %(gem "solid_queue"\n))
    File.write(File.join(destination_root, "config/recurring.yml"), "production:\n")

    run_generator
    run_generator

    assert_file "config/recurring.yml" do |content|
      assert_equal 1, content.scan("sweep_abandoned_wizards:").size
    end
    assert_file "config/initializers/plutonium.rb" do |content|
      assert_equal 1, content.scan("config.wizards.enabled = true").size
    end
  end

  test "without solid_queue it still enables, and schedules nothing" do
    File.write(File.join(destination_root, "Gemfile"), %(gem "rails"\n))

    run_generator

    # Enabling is the part that must happen either way; scheduling is the host's
    # problem when there is no scheduler to write to.
    assert_file "config/initializers/plutonium.rb" do |content|
      assert_match(/config\.wizards\.enabled = true/, content)
    end
    assert_no_file "config/recurring.yml"
  end
end
