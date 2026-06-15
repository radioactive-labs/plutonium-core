# frozen_string_literal: true

require "test_helper"

# Covers the engine-level `shell` DSL added by Plutonium::Portal::Engine:
# its live cascade to the global config, and the deliberate decision to put
# it on portal engines only (not feature-package engines).
class PortalEngineShellTest < ActiveSupport::TestCase
  def with_shell(value)
    original = Plutonium.configuration.shell
    Plutonium.configuration.shell = value
    yield
  ensure
    Plutonium.configuration.shell = original
  end

  # --- Live cascade to the global config (gap #1) ---

  test "engine shell cascades live to the global config when unset" do
    AdminPortal::Engine.instance_variable_set(:@shell, nil)
    with_shell(:plain) { assert_equal :plain, AdminPortal::Engine.shell }
    with_shell(:modern) { assert_equal :modern, AdminPortal::Engine.shell }
  end

  test "engine shell override takes precedence over the global config" do
    AdminPortal::Engine.shell(:classic)
    with_shell(:modern) { assert_equal :classic, AdminPortal::Engine.shell }
  ensure
    AdminPortal::Engine.instance_variable_set(:@shell, nil)
  end

  # --- Placement: portal engines only, not feature packages (gap #2) ---

  test "shell DSL is defined on portal engines" do
    assert_respond_to AdminPortal::Engine, :shell
  end

  test "shell DSL is not defined on feature-package engines" do
    refute_respond_to Catalog::Engine, :shell
  end
end
