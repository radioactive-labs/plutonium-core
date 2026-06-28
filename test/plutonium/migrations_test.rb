# frozen_string_literal: true

require "test_helper"

module Plutonium
  class MigrationsTest < Minitest::Test
    def setup
      Plutonium::Migrations.reset!
      # RESTORE the original flag in teardown (don't hard-code false): the dummy app
      # enables wizards at boot, and leaving it false here would make any later test
      # that reloads routes (e.g. ResumeTest) silently drop the wizard routes.
      @was_enabled = Plutonium.configuration.wizards.enabled
    end

    def teardown
      Plutonium::Migrations.reset!
      Plutonium.configuration.wizards.enabled = @was_enabled
    end

    def test_enabled_paths_excludes_disabled_features
      Plutonium.configuration.wizards.enabled = false
      Plutonium::Migrations.register(:wizards, "/some/path")

      assert_empty Plutonium::Migrations.enabled_paths
    end

    def test_enabled_paths_includes_enabled_features
      Plutonium.configuration.wizards.enabled = true
      Plutonium::Migrations.register(:wizards, "/some/path")

      assert_includes Plutonium::Migrations.enabled_paths, "/some/path"
    end

    def test_enabled_paths_ignores_unknown_features
      Plutonium::Migrations.register(:nonexistent_feature, "/other/path")

      assert_empty Plutonium::Migrations.enabled_paths
    end

    def test_register_uses_symbol_keys
      Plutonium.configuration.wizards.enabled = true
      Plutonium::Migrations.register("wizards", "/string/path")

      assert_includes Plutonium::Migrations.enabled_paths, "/string/path"
    end
  end
end
