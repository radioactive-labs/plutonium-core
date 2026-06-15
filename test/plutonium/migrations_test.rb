# frozen_string_literal: true

require "test_helper"

module Plutonium
  class MigrationsTest < Minitest::Test
    def setup
      Plutonium::Migrations.reset!
    end

    def teardown
      Plutonium::Migrations.reset!
      Plutonium.configuration.wizards.enabled = false
    end

    def test_enabled_paths_excludes_disabled_features
      Plutonium.configuration.wizards.enabled = false
      Plutonium::Migrations.register(:wizards, "/some/path")

      assert_empty Plutonium::Migrations.enabled_paths
    ensure
      Plutonium.configuration.wizards.enabled = false
    end

    def test_enabled_paths_includes_enabled_features
      Plutonium.configuration.wizards.enabled = true
      Plutonium::Migrations.register(:wizards, "/some/path")

      assert_includes Plutonium::Migrations.enabled_paths, "/some/path"
    ensure
      Plutonium.configuration.wizards.enabled = false
    end

    def test_enabled_paths_ignores_unknown_features
      Plutonium::Migrations.register(:nonexistent_feature, "/other/path")

      assert_empty Plutonium::Migrations.enabled_paths
    end

    def test_register_uses_symbol_keys
      Plutonium.configuration.wizards.enabled = true
      Plutonium::Migrations.register("wizards", "/string/path")

      assert_includes Plutonium::Migrations.enabled_paths, "/string/path"
    ensure
      Plutonium.configuration.wizards.enabled = false
    end
  end
end
