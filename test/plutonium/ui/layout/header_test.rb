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

  # ---------------------------------------------------------------------------
  # Classic shell (default)
  # ---------------------------------------------------------------------------

  test "renders a nav element" do
    html = render_html(build_component)
    assert_includes html, "<nav"
  end

  test "nav is fixed and positioned at top-0" do
    html = render_html(build_component)
    assert_includes html, "fixed"
    assert_includes html, "top-0"
  end

  test "nav has z-50 stacking context" do
    html = render_html(build_component)
    assert_includes html, "z-50"
  end

  test "has resource-header data-controller" do
    html = render_html(build_component)
    assert_includes html, 'data-controller="resource-header"'
  end

  test "renders sidebar toggle button" do
    html = render_html(build_component)
    assert_includes html, "resource-header#toggleDrawer"
  end

  test "renders action slots when provided" do
    component = build_component
    component.with_action { "ACTION_BTN" }
    html = render_html(component)
    assert_includes html, "ACTION_BTN"
  end

  test "does not include Topbar-specific h-12 height" do
    html = render_html(build_component)
    refute_includes html, "h-12"
  end
end
