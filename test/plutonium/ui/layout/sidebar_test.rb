# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Layout::SidebarTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def build_component(&block)
    Plutonium::UI::Layout::Sidebar.new
  end

  def render_html(component, &block)
    if block
      component.call(&block)
    else
      component.call
    end
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

  test "classic shell renders aside with id sidebar-navigation" do
    html = render_html(build_component)
    assert_includes html, 'id="sidebar-navigation"'
    assert_includes html, "<aside"
  end

  test "classic shell aside is w-64 wide" do
    html = render_html(build_component)
    assert_includes html, "w-64"
  end

  test "classic shell aside has sidebar data-controller only" do
    html = render_html(build_component)
    assert_includes html, 'data-controller="sidebar"'
    refute_includes html, "icon-rail"
  end

  test "classic shell has pt-14 top padding (below classic header)" do
    html = render_html(build_component)
    assert_includes html, "pt-14"
  end

  test "classic shell yields content into scroll div" do
    component = build_component
    html = component.call { "SIDEBAR_CONTENT" }
    assert_includes html, "SIDEBAR_CONTENT"
  end

  test "classic shell content div has turbo-permanent" do
    html = render_html(build_component)
    assert_includes html, "data-turbo-permanent"
  end

  # ---------------------------------------------------------------------------
  # Modern shell
  # ---------------------------------------------------------------------------

  test "modern shell renders aside with id sidebar-navigation" do
    with_modern_shell do
      html = render_html(build_component)
      assert_includes html, 'id="sidebar-navigation"'
      assert_includes html, "<aside"
    end
  end

  test "modern shell aside is w-14 (56px icon rail width)" do
    with_modern_shell do
      html = render_html(build_component)
      assert_includes html, "w-14"
    end
  end

  test "modern shell aside has sidebar and icon-rail data-controllers" do
    with_modern_shell do
      html = render_html(build_component)
      assert_includes html, "sidebar"
      assert_includes html, "icon-rail"
    end
  end

  test "modern shell does not have w-64 wide sidebar" do
    with_modern_shell do
      html = render_html(build_component)
      refute_includes html, "w-64"
    end
  end

  test "modern shell does not have pt-14 (no top offset — rail is full height)" do
    with_modern_shell do
      html = render_html(build_component)
      refute_includes html, "pt-14"
    end
  end

  test "modern shell yields content into scroll div" do
    with_modern_shell do
      component = build_component
      html = component.call { "RAIL_CONTENT" }
      assert_includes html, "RAIL_CONTENT"
    end
  end

  test "modern shell content div has turbo-permanent" do
    with_modern_shell do
      html = render_html(build_component)
      assert_includes html, "data-turbo-permanent"
    end
  end

  test "modern shell renders pin button in footer" do
    with_modern_shell do
      html = render_html(build_component)
      assert_includes html, "icon-rail#togglePin"
    end
  end

  test "modern shell pin button has collapse icon span" do
    with_modern_shell do
      html = render_html(build_component)
      assert_includes html, "icon-rail-pin-collapse"
    end
  end

  test "modern shell pin button has expand icon span" do
    with_modern_shell do
      html = render_html(build_component)
      assert_includes html, "icon-rail-pin-expand"
    end
  end

  test "modern shell has -translate-x-full mobile hidden" do
    with_modern_shell do
      html = render_html(build_component)
      assert_includes html, "-translate-x-full"
    end
  end

  test "modern shell has lg:translate-x-0 desktop visible" do
    with_modern_shell do
      html = render_html(build_component)
      assert_includes html, "lg:translate-x-0"
    end
  end
end
