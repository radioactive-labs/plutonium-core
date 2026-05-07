# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::SidebarMenuTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Minimal stand-in for a Phlexi::Menu::Item
  StubItem = Struct.new(:label, :url, :icon, :items, :leading_badge, :trailing_badge, keyword_init: true) do
    def active?(*)
      false
    end
  end

  ActiveStubItem = Struct.new(:label, :url, :icon, :items, :leading_badge, :trailing_badge, keyword_init: true) do
    def active?(*)
      true
    end
  end

  StubMenu = Struct.new(:items)

  class StubIcon < Phlex::HTML
    def initialize(class: nil)
      @css_class = binding.local_variable_get(:class)
    end

    def view_template
      span(class: @css_class) { "ICON" }
    end
  end

  def build_component(menu)
    Plutonium::UI::SidebarMenu.new(menu)
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
    menu = StubMenu.new([StubItem.new(label: "Home", url: "/", icon: nil, items: [])])
    html = render_html(build_component(menu))
    assert_includes html, "<nav"
  end

  test "classic shell renders labelled links" do
    menu = StubMenu.new([StubItem.new(label: "Dashboard", url: "/dashboard", icon: nil, items: [])])
    html = render_html(build_component(menu))
    assert_includes html, "Dashboard"
    assert_includes html, 'href="/dashboard"'
  end

  test "classic shell does not render icon-rail markup" do
    menu = StubMenu.new([StubItem.new(label: "Home", url: "/", icon: nil, items: [])])
    html = render_html(build_component(menu))
    refute_includes html, "icon-rail-leaf"
    refute_includes html, "icon-rail-parent"
    refute_includes html, "icon-rail-flyout"
  end

  # ---------------------------------------------------------------------------
  # Modern shell
  # ---------------------------------------------------------------------------

  test "modern shell renders leaf items with icon-rail-leaf class" do
    with_modern_shell do
      menu = StubMenu.new([StubItem.new(label: "Dashboard", url: "/dashboard", icon: nil, items: [])])
      html = render_html(build_component(menu))
      assert_includes html, "icon-rail-leaf"
    end
  end

  test "modern shell leaf item has title and aria-label" do
    with_modern_shell do
      menu = StubMenu.new([StubItem.new(label: "Reports", url: "/reports", icon: nil, items: [])])
      html = render_html(build_component(menu))
      assert_includes html, 'title="Reports"'
      assert_includes html, 'aria-label="Reports"'
    end
  end

  test "modern shell leaf item has href" do
    with_modern_shell do
      menu = StubMenu.new([StubItem.new(label: "Home", url: "/home", icon: nil, items: [])])
      html = render_html(build_component(menu))
      assert_includes html, 'href="/home"'
    end
  end

  test "modern shell leaf item has hidden label span" do
    with_modern_shell do
      menu = StubMenu.new([StubItem.new(label: "Reports", url: "/reports", icon: nil, items: [])])
      html = render_html(build_component(menu))
      assert_includes html, "icon-rail-label"
      assert_includes html, "hidden"
    end
  end

  test "modern shell parent item renders flyout markup" do
    with_modern_shell do
      child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
      parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
      menu = StubMenu.new([parent])
      html = render_html(build_component(menu))

      assert_includes html, "icon-rail-flyout"
      assert_includes html, "icon-rail-flyout-inner"
      assert_includes html, "icon-rail-flyout-label"
      assert_includes html, "icon-rail-flyout-item"
    end
  end

  test "modern shell parent item renders inline children for pinned mode" do
    with_modern_shell do
      child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
      parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
      menu = StubMenu.new([parent])
      html = render_html(build_component(menu))

      assert_includes html, "icon-rail-children"
      assert_includes html, "resource-collapse-target"
    end
  end

  test "modern shell parent item has chevron span" do
    with_modern_shell do
      child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
      parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
      menu = StubMenu.new([parent])
      html = render_html(build_component(menu))

      assert_includes html, "icon-rail-chevron"
    end
  end

  test "modern shell parent trigger uses resource-collapse#toggle" do
    with_modern_shell do
      child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
      parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
      menu = StubMenu.new([parent])
      html = render_html(build_component(menu))

      assert_includes html, "resource-collapse#toggle"
    end
  end

  test "modern shell child items appear in flyout with correct href" do
    with_modern_shell do
      child = StubItem.new(label: "Child Page", url: "/child", icon: nil, items: [])
      parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
      menu = StubMenu.new([parent])
      html = render_html(build_component(menu))

      assert_includes html, "Child Page"
      assert_includes html, 'href="/child"'
    end
  end

  test "modern shell with icon renders icon component" do
    with_modern_shell do
      menu = StubMenu.new([StubItem.new(label: "Home", url: "/", icon: StubIcon, items: [])])
      html = render_html(build_component(menu))
      assert_includes html, "ICON"
    end
  end

  test "modern shell without icon renders 2-letter abbreviation" do
    with_modern_shell do
      menu = StubMenu.new([StubItem.new(label: "Customers", url: "/customers", icon: nil, items: [])])
      html = render_html(build_component(menu))
      assert_includes html, "Cu"
    end
  end

  test "modern shell active leaf item receives primary bg class" do
    with_modern_shell do
      menu = StubMenu.new([ActiveStubItem.new(label: "Active", url: "/active", icon: nil, items: [])])
      html = render_html(build_component(menu))
      assert_includes html, "bg-primary-100"
      assert_includes html, "text-primary-700"
    end
  end

  test "modern shell inactive leaf item has muted text" do
    with_modern_shell do
      menu = StubMenu.new([StubItem.new(label: "Inactive", url: "/inactive", icon: nil, items: [])])
      html = render_html(build_component(menu))
      assert_includes html, "text-[var(--pu-text-muted)]"
      refute_includes html, "bg-primary-100"
    end
  end

  test "modern shell child link appears in both flyout and inline tree" do
    with_modern_shell do
      child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
      parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
      menu = StubMenu.new([parent])
      html = render_html(build_component(menu))

      assert html.scan('href="/child"').length >= 2, "child href should appear at least twice"
    end
  end
end
