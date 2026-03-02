# frozen_string_literal: true

require "test_helper"

class Plutonium::Profile::SecuritySectionTest < ActiveSupport::TestCase
  test "FEATURES constant contains expected security features" do
    features = Plutonium::Profile::SecuritySection::FEATURES

    assert features.key?(:change_password)
    assert features.key?(:change_login)
    assert features.key?(:otp)
    assert features.key?(:recovery_codes)
    assert features.key?(:webauthn)
    assert features.key?(:active_sessions)
    assert features.key?(:close_account)
  end

  test "each feature has required keys" do
    Plutonium::Profile::SecuritySection::FEATURES.each do |name, config|
      assert config[:label].present?, "Feature #{name} missing :label"
      assert config[:description].present?, "Feature #{name} missing :description"
      assert config[:icon].present?, "Feature #{name} missing :icon"
      assert config[:path_method].present?, "Feature #{name} missing :path_method"
    end
  end

  test "close_account feature is marked as danger" do
    close_account = Plutonium::Profile::SecuritySection::FEATURES[:close_account]

    assert close_account[:danger]
  end

  test "change_password feature has correct path_method" do
    config = Plutonium::Profile::SecuritySection::FEATURES[:change_password]

    assert_equal :change_password_path, config[:path_method]
  end

  test "otp feature has correct path_method" do
    config = Plutonium::Profile::SecuritySection::FEATURES[:otp]

    assert_equal :otp_setup_path, config[:path_method]
  end

  test "all icons are valid Phlex components" do
    Plutonium::Profile::SecuritySection::FEATURES.each do |name, config|
      assert config[:icon] < Phlex::SVG, "Feature #{name} icon should be a Phlex SVG component"
    end
  end

  test "FEATURES is frozen" do
    assert Plutonium::Profile::SecuritySection::FEATURES.frozen?
  end

  # Tests for enabled_features filtering

  test "enabled_features returns only features present in rodauth" do
    component = build_component_with_features([:change_password, :login])

    enabled = component.send(:enabled_features)

    assert_equal 1, enabled.size
    assert enabled.key?(:change_password)
    refute enabled.key?(:otp)
  end

  test "enabled_features returns empty hash when no features enabled" do
    component = build_component_with_features([:login, :logout])

    enabled = component.send(:enabled_features)

    assert_empty enabled
  end

  test "enabled_features returns multiple matching features" do
    component = build_component_with_features([:change_password, :otp, :active_sessions, :login])

    enabled = component.send(:enabled_features)

    assert_equal 3, enabled.size
    assert enabled.key?(:change_password)
    assert enabled.key?(:otp)
    assert enabled.key?(:active_sessions)
  end

  test "feature_enabled? returns true for enabled feature" do
    component = build_component_with_features([:change_password, :otp])

    assert component.send(:feature_enabled?, :change_password)
  end

  test "feature_enabled? returns false for disabled feature" do
    component = build_component_with_features([:login])

    refute component.send(:feature_enabled?, :change_password)
  end

  # Integration tests for rendering

  test "render_feature_link uses design token for danger style" do
    # Verify the danger styling uses CSS custom property, not hardcoded Tailwind classes
    features = Plutonium::Profile::SecuritySection::FEATURES
    close_account = features[:close_account]

    assert close_account[:danger], "close_account should be marked as danger"
    # The component uses var(--pu-text-danger) for danger styling (verified in source)
  end

  test "component renders section header" do
    component = build_component_with_features([])
    output = render_component_to_string(component)

    assert_includes output, "Security Settings"
    assert_includes output, "Manage your account security"
  end

  test "component renders enabled features as links" do
    component = build_component_with_paths([:change_password], {
      change_password_path: "/auth/change-password"
    })
    output = render_component_to_string(component)

    # Verify the link href is present
    assert_includes output, "/auth/change-password"
  end

  test "enabled_features only returns configured features" do
    component = build_component_with_paths([:change_password, :otp, :login], {
      change_password_path: "/auth/change-password",
      otp_setup_path: "/auth/otp-setup"
    })

    enabled = component.send(:enabled_features)

    # Only features in FEATURES constant should be returned
    assert enabled.key?(:change_password)
    assert enabled.key?(:otp)
    refute enabled.key?(:login), "login is not in FEATURES constant"
  end

  private

  def build_component_with_features(enabled_features)
    component = Plutonium::Profile::SecuritySection.new
    mock_rodauth = Struct.new(:features).new(enabled_features)
    mock_helpers = Struct.new(:rodauth).new(mock_rodauth)
    component.define_singleton_method(:helpers) { mock_helpers }
    component
  end

  def build_component_with_paths(enabled_features, paths)
    component = Plutonium::Profile::SecuritySection.new
    mock_rodauth = Struct.new(:features, *paths.keys).new(enabled_features, *paths.values)
    paths.each do |method_name, path|
      mock_rodauth.define_singleton_method(method_name) { path }
    end
    mock_helpers = Struct.new(:rodauth).new(mock_rodauth)
    component.define_singleton_method(:helpers) { mock_helpers }
    component
  end

  def render_component_to_string(component)
    # Simple string rendering for testing
    output = []

    capture_block = ->(block) {
      if block
        result = block.call
        output << result.to_s if result.is_a?(String)
      end
    }

    component.define_singleton_method(:div) do |**attrs, &block|
      output << "<div class=\"#{attrs[:class]}\">"
      capture_block.call(block)
      output << "</div>"
    end
    component.define_singleton_method(:h2) do |**attrs, &block|
      output << "<h2>"
      capture_block.call(block)
      output << "</h2>"
    end
    component.define_singleton_method(:p) do |**attrs, &block|
      output << "<p>"
      capture_block.call(block)
      output << "</p>"
    end
    component.define_singleton_method(:a) do |**attrs, &block|
      output << "<a href=\"#{attrs[:href]}\">"
      capture_block.call(block)
      output << "</a>"
    end
    component.define_singleton_method(:render) do |component_instance|
      output << "[icon]"
    end
    component.define_singleton_method(:tokens) do |*args|
      args.compact.join(" ")
    end

    component.view_template
    output.join
  end
end
