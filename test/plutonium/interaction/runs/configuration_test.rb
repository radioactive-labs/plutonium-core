# frozen_string_literal: true

require "test_helper"

class Plutonium::Interaction::Runs::ConfigurationTest < ActiveSupport::TestCase
  test "default values" do
    config = Plutonium::Interaction::Runs::Configuration.new

    assert_equal false, config.enabled
    assert_equal :default, config.queue
  end

  test "migration path is surfaced only when enabled" do
    # Re-registering the path the railtie already registered at boot is
    # idempotent, and NOT redundant: MigrationsTest#teardown empties the shared
    # registry without restoring it, so on any run where that file happens to go
    # first this test would otherwise assert against an empty registry.
    path = Plutonium.root.join("db/migrate/interaction_runs").to_s
    Plutonium::Migrations.register(:interaction_runs, path)

    Plutonium.configuration.interaction_runs.enabled = false
    refute_includes Plutonium::Migrations.enabled_paths, path

    Plutonium.configuration.interaction_runs.enabled = true
    assert_includes Plutonium::Migrations.enabled_paths, path
  ensure
    Plutonium.configuration.interaction_runs.enabled = false
  end
end
