# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Layout::IconRailTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Minimal stand-in for a Phlexi::Menu::Item
  StubItem = Struct.new(:label, :url, :icon, :items, keyword_init: true) do
    def active?(*)
      false
    end
  end

  ActiveStubItem = Struct.new(:label, :url, :icon, :items, keyword_init: true) do
    def active?(*)
      true
    end
  end

  # Minimal menu wrapper that exposes #items
  StubMenu = Struct.new(:items)

  # Minimal icon component class — renders a recognisable string
  class StubIcon < Phlex::HTML
    def initialize(class: nil)
      @css_class = binding.local_variable_get(:class)
    end

    def view_template
      span(class: @css_class) { "ICON" }
    end
  end

  # Build a component with optional menu and yield block for slots.
  def build_component(menu: nil, &block)
    component = Plutonium::UI::Layout::IconRail.new(menu: menu)
    component.instance_exec(&block) if block
    component
  end

  # Render via actual Phlex HTML output.
  def render_html(component)
    component.call
  end

  # ---------------------------------------------------------------------------
  # Structure tests
  # ---------------------------------------------------------------------------

  test "renders aside element with id sidebar-navigation" do
    html = render_html(build_component)
    assert_includes html, 'id="sidebar-navigation"'
    assert_includes html, "<aside"
  end

  test "aside has w-14 width class (56px)" do
    html = render_html(build_component)
    assert_includes html, "w-14"
  end

  test "aside is fixed top-0 left-0 full-height" do
    html = render_html(build_component)
    assert_includes html, "fixed"
    assert_includes html, "top-0"
    assert_includes html, "left-0"
    assert_includes html, "h-screen"
  end

  test "aside has sidebar data-controller" do
    html = render_html(build_component)
    assert_includes html, 'data-controller="sidebar"'
  end

  test "mobile-hidden class present (-translate-x-full)" do
    html = render_html(build_component)
    assert_includes html, "-translate-x-full"
  end

  test "desktop visible class present (lg:translate-x-0)" do
    html = render_html(build_component)
    assert_includes html, "lg:translate-x-0"
  end

  test "nav section has turbo-permanent data attribute" do
    html = render_html(build_component)
    assert_includes html, "data-turbo-permanent"
  end

  # ---------------------------------------------------------------------------
  # Brand slot
  # ---------------------------------------------------------------------------

  test "brand slot renders into top section when provided" do
    component = Plutonium::UI::Layout::IconRail.new
    component.with_brand { "BRAND_MARK" }
    html = render_html(component)
    assert_includes html, "BRAND_MARK"
  end

  test "brand section renders even when slot is empty" do
    html = render_html(build_component)
    # The brand div wrapper is always present
    assert_includes html, "border-b border-[var(--pu-border)]"
  end

  # ---------------------------------------------------------------------------
  # Menu item rendering
  # ---------------------------------------------------------------------------

  test "renders anchor tags for menu items" do
    items = [
      StubItem.new(label: "Dashboard", url: "/dashboard", icon: nil, items: []),
      StubItem.new(label: "Customers", url: "/customers", icon: nil, items: [])
    ]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, 'href="/dashboard"'
    assert_includes html, 'href="/customers"'
  end

  test "renders correct number of anchor elements for two items" do
    items = [
      StubItem.new(label: "Alpha", url: "/alpha", icon: nil, items: []),
      StubItem.new(label: "Beta", url: "/beta", icon: nil, items: [])
    ]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_equal 2, html.scan("<a ").length
  end

  test "anchor title and aria-label match item label" do
    items = [StubItem.new(label: "Reports", url: "/reports", icon: nil, items: [])]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, 'title="Reports"'
    assert_includes html, 'aria-label="Reports"'
  end

  # ---------------------------------------------------------------------------
  # Icon vs abbreviation fallback
  # ---------------------------------------------------------------------------

  test "item with icon renders the icon component" do
    items = [StubItem.new(label: "Home", url: "/", icon: StubIcon, items: [])]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, "ICON"
  end

  test "item without icon renders 2-letter abbreviation" do
    items = [StubItem.new(label: "Customers", url: "/customers", icon: nil, items: [])]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, "Cu"
    refute_includes html, "ICON"
  end

  test "abbreviation for single-word label uses first two letters capitalised" do
    component = build_component
    assert_equal "Cu", component.send(:abbreviate, "Customers")
    assert_equal "Re", component.send(:abbreviate, "Reports")
    assert_equal "Ab", component.send(:abbreviate, "AB")
  end

  test "abbreviation strips non-letter characters" do
    component = build_component
    # "My Tasks" — non-letters stripped → "MyTasks" → first 2 = "My"
    assert_equal "My", component.send(:abbreviate, "My Tasks")
  end

  # ---------------------------------------------------------------------------
  # Active / inactive states
  # ---------------------------------------------------------------------------

  test "active item receives bg-primary-100 class" do
    items = [ActiveStubItem.new(label: "Active Page", url: "/active", icon: nil, items: [])]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, "bg-primary-100"
    assert_includes html, "text-primary-700"
  end

  test "inactive item does not receive bg-primary-100" do
    items = [StubItem.new(label: "Other Page", url: "/other", icon: nil, items: [])]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    refute_includes html, "bg-primary-100"
  end

  test "inactive item receives muted text class" do
    items = [StubItem.new(label: "Other Page", url: "/other", icon: nil, items: [])]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, "text-[var(--pu-text-muted)]"
  end

  test "active item gets dark mode classes" do
    items = [ActiveStubItem.new(label: "Active", url: "/active", icon: nil, items: [])]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, "dark:bg-primary-900/40"
    assert_includes html, "dark:text-primary-300"
  end

  # ---------------------------------------------------------------------------
  # Edge cases
  # ---------------------------------------------------------------------------

  test "renders without error when menu is nil" do
    html = render_html(build_component(menu: nil))
    assert_includes html, "sidebar-navigation"
  end

  test "nested items are ignored (depth limit respected)" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    parent = StubItem.new(label: "Parent", url: "/parent", icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    # Parent link is rendered, child link is not (depth 1 limit)
    assert_includes html, 'href="/parent"'
    refute_includes html, 'href="/child"'
  end
end
