# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Layout::HeaderTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def build_component(&block)
    component = Plutonium::UI::Layout::Header.new
    component.instance_exec(&block) if block
    component
  end

  def render_html(component)
    component.call
  end

  def with_modern_shell
    Plutonium.configure { |c| c.shell = :modern }
    yield
  ensure
    Plutonium.configure { |c| c.shell = :classic }
  end

  # ---------------------------------------------------------------------------
  # Classic shell (default)
  # ---------------------------------------------------------------------------

  test "classic shell renders a nav element" do
    html = render_html(build_component)
    assert_includes html, "<nav"
  end

  test "classic shell nav is fixed and positioned at top-0" do
    html = render_html(build_component)
    assert_includes html, "fixed"
    assert_includes html, "top-0"
  end

  test "classic shell has z-50 stacking context" do
    html = render_html(build_component)
    assert_includes html, "z-50"
  end

  test "classic shell has sidebar data-controller" do
    html = render_html(build_component)
    assert_includes html, 'data-controller="resource-header"'
  end

  test "classic shell renders sidebar toggle button" do
    html = render_html(build_component)
    assert_includes html, "resource-header#toggleDrawer"
  end

  test "classic shell renders action slots when provided" do
    component = build_component
    component.with_action { "ACTION_BTN" }
    html = render_html(component)
    assert_includes html, "ACTION_BTN"
  end

  test "classic shell does not include Topbar-specific h-12 height" do
    html = render_html(build_component)
    refute_includes html, "h-12"
  end

  # ---------------------------------------------------------------------------
  # Modern shell
  # ---------------------------------------------------------------------------

  test "modern shell renders nav element via Topbar" do
    with_modern_shell do
      html = render_html(build_component)
      assert_includes html, "<nav"
    end
  end

  test "modern shell includes h-12 topbar height" do
    with_modern_shell do
      html = render_html(build_component)
      assert_includes html, "h-12"
    end
  end

  test "modern shell includes lg:left-14 topbar offset" do
    with_modern_shell do
      html = render_html(build_component)
      assert_includes html, "lg:left-14"
    end
  end

  test "modern shell uses z-30 (topbar stacking context)" do
    with_modern_shell do
      html = render_html(build_component)
      assert_includes html, "z-30"
    end
  end

  test "modern shell passes action slots through to topbar" do
    with_modern_shell do
      component = build_component
      component.with_action { "MODERN_ACTION" }
      html = render_html(component)
      assert_includes html, "MODERN_ACTION"
    end
  end

  test "modern shell does not include z-50 classic header stacking" do
    with_modern_shell do
      html = render_html(build_component)
      refute_includes html, "z-50"
    end
  end
end
