# frozen_string_literal: true

require "test_helper"

class Plutonium::Interaction::Async::ConfigurationTest < ActiveSupport::TestCase
  test "default values" do
    config = Plutonium::Interaction::Async::Configuration.new

    assert_equal false, config.enabled
    assert_equal :default, config.queue
    assert_equal 1.hour, config.stall_after
  end

  test "migration path is surfaced only when enabled" do
    # Capture and restore, rather than resetting to a literal. The dummy app
    # enables this at boot so its migration runs against the test DB, and this
    # suite has no transactional rollback — so writing a hardcoded `false` here
    # disabled the feature for every test that ran afterwards in the same
    # process. Anything reading the flag (Page::Index's run banner does) then
    # silently rendered nothing, and failed only under orders that put this file
    # first.
    was_enabled = Plutonium.configuration.async_interactions.enabled

    # Re-registering the path the railtie already registered at boot is
    # idempotent, and NOT redundant: MigrationsTest#teardown empties the shared
    # registry without restoring it, so on any run where that file happens to go
    # first this test would otherwise assert against an empty registry.
    path = Plutonium.root.join("db/migrate/async_interactions").to_s
    Plutonium::Migrations.register(:async_interactions, path)

    Plutonium.configuration.async_interactions.enabled = false
    refute_includes Plutonium::Migrations.enabled_paths, path

    Plutonium.configuration.async_interactions.enabled = true
    assert_includes Plutonium::Migrations.enabled_paths, path
  ensure
    Plutonium.configuration.async_interactions.enabled = was_enabled
  end
end
