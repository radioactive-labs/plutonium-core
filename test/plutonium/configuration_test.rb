# frozen_string_literal: true

require "test_helper"

class Plutonium::Configuration::AssetConfigurationTest < Minitest::Test
  def setup
    @assets = Plutonium::Configuration::AssetConfiguration.new
  end

  def test_defaults_match_documented_values
    assert_equal "plutonium.png", @assets.logo
    assert_equal "plutonium.ico", @assets.favicon
    assert_equal "plutonium.css", @assets.stylesheet
    assert_equal "plutonium.min.js", @assets.script
  end

  def test_customized_is_false_for_fresh_configuration
    refute @assets.customized?(:logo)
    refute @assets.customized?(:favicon)
    refute @assets.customized?(:stylesheet)
    refute @assets.customized?(:script)
  end

  def test_setting_stylesheet_marks_only_stylesheet_customized
    @assets.stylesheet = "application"

    assert @assets.customized?(:stylesheet)
    refute @assets.customized?(:script)
    refute @assets.customized?(:logo)
    refute @assets.customized?(:favicon)
    assert_equal "application", @assets.stylesheet
  end

  def test_setting_script_marks_only_script_customized
    @assets.script = "application"

    assert @assets.customized?(:script)
    refute @assets.customized?(:stylesheet)
  end

  def test_assigning_default_value_still_marks_customized
    @assets.stylesheet = "plutonium.css"

    assert @assets.customized?(:stylesheet),
      "Explicit assignment counts as customization even when the new value matches the default"
  end

  def test_customized_with_unknown_attr_returns_false
    refute @assets.customized?(:nonexistent)
  end

  def test_logo_and_favicon_setters_track_customization
    @assets.logo = "custom.png"
    @assets.favicon = "custom.ico"

    assert @assets.customized?(:logo)
    assert @assets.customized?(:favicon)
  end
end
