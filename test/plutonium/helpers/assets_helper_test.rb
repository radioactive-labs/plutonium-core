# frozen_string_literal: true

require "test_helper"

class Plutonium::Helpers::AssetsHelperTest < Minitest::Test
  class TestHost
    include Plutonium::Helpers::AssetsHelper
  end

  def setup
    @host = TestHost.new
    @original_config = Plutonium.instance_variable_get(:@configuration)
    Plutonium.instance_variable_set(:@configuration, Plutonium::Configuration.new)
  end

  def teardown
    Plutonium.instance_variable_set(:@configuration, @original_config)
  end

  def test_non_dev_mode_returns_fallback_for_default_stylesheet
    Plutonium.configuration.development = false

    url = @host.send(:resource_asset_url_for, :css, "plutonium.css")

    assert_equal "plutonium.css", url
  end

  def test_non_dev_mode_returns_fallback_for_customized_stylesheet
    Plutonium.configuration.development = false
    Plutonium.configuration.assets.stylesheet = "application"

    url = @host.send(:resource_asset_url_for, :css, "application")

    assert_equal "application", url
  end

  def test_dev_mode_with_default_stylesheet_uses_build_url
    Plutonium.configuration.development = true

    @host.define_singleton_method(:resource_development_asset_url) { |*| "/build/fake-asset" }
    url = @host.send(:resource_asset_url_for, :css, "plutonium.css")

    assert_match %r{\A/build/}, url,
      "Expected dev override to substitute a /build/* URL when stylesheet is at default; got #{url.inspect}"
  ensure
    @host.singleton_class.send(:undef_method, :resource_development_asset_url)
  end

  def test_dev_mode_with_customized_stylesheet_returns_fallback
    Plutonium.configuration.development = true
    Plutonium.configuration.assets.stylesheet = "application"

    url = @host.send(:resource_asset_url_for, :css, "application")

    assert_equal "application", url,
      "Customized stylesheet must opt out of the dev URL override"
  end

  def test_dev_mode_with_default_script_uses_build_url
    Plutonium.configuration.development = true

    @host.define_singleton_method(:resource_development_asset_url) { |*| "/build/fake-asset" }
    url = @host.send(:resource_asset_url_for, :js, "plutonium.min.js")

    assert_match %r{\A/build/}, url
  ensure
    @host.singleton_class.send(:undef_method, :resource_development_asset_url)
  end

  def test_dev_mode_with_customized_script_returns_fallback
    Plutonium.configuration.development = true
    Plutonium.configuration.assets.script = "application"

    url = @host.send(:resource_asset_url_for, :js, "application")

    assert_equal "application", url
  end

  def test_customizing_stylesheet_does_not_affect_script_override
    Plutonium.configuration.development = true
    Plutonium.configuration.assets.stylesheet = "application"

    @host.define_singleton_method(:resource_development_asset_url) { |*| "/build/fake-asset" }
    js_url = @host.send(:resource_asset_url_for, :js, "plutonium.min.js")

    assert_match %r{\A/build/}, js_url,
      "Customizing stylesheet only must not silence the dev override on script"
  ensure
    @host.singleton_class.send(:undef_method, :resource_development_asset_url)
  end
end
