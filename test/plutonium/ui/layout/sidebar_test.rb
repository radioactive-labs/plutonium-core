# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Layout::SidebarTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def build_component
    Plutonium::UI::Layout::Sidebar.new
  end

  def render_html(component, &block)
    if block
      component.call(&block)
    else
      component.call
    end
  end

  # ---------------------------------------------------------------------------
  # Classic shell
  # ---------------------------------------------------------------------------

  test "renders aside with id sidebar-navigation" do
    html = render_html(build_component)
    assert_includes html, 'id="sidebar-navigation"'
    assert_includes html, "<aside"
  end

  test "aside is w-64 wide" do
    html = render_html(build_component)
    assert_includes html, "w-64"
  end

  test "aside has sidebar data-controller only" do
    html = render_html(build_component)
    assert_includes html, 'data-controller="sidebar"'
    refute_includes html, "icon-rail"
  end

  test "has pt-14 top padding (below classic header)" do
    html = render_html(build_component)
    assert_includes html, "pt-14"
  end

  test "yields content into scroll div" do
    component = build_component
    html = component.call { "SIDEBAR_CONTENT" }
    assert_includes html, "SIDEBAR_CONTENT"
  end

  test "content div has turbo-permanent" do
    html = render_html(build_component)
    assert_includes html, "data-turbo-permanent"
  end
end
