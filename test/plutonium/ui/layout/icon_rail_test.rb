# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Layout::IconRailTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Minimal stand-in for a Phlexi::Menu::Item. `options` mirrors the real
  # Item#options hash (extra kwargs like :target / :rel).
  StubItem = Struct.new(:label, :url, :icon, :items, :options, keyword_init: true) do
    def active?(*)
      false
    end
  end

  ActiveStubItem = Struct.new(:label, :url, :icon, :items, :options, keyword_init: true) do
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

  test "aside has overflow-x-hidden (width is CSS-controlled, not Tailwind utility)" do
    html = render_html(build_component)
    assert_includes html, "overflow-x-hidden"
    refute_includes html, "w-14"
  end

  test "aside is fixed top-0 left-0 full-height" do
    html = render_html(build_component)
    assert_includes html, "fixed"
    assert_includes html, "top-0"
    assert_includes html, "left-0"
    assert_includes html, "h-screen"
  end

  test "aside has sidebar and icon-rail data-controllers" do
    html = render_html(build_component)
    assert_includes html, "sidebar"
    assert_includes html, "icon-rail"
  end

  test "mobile-hidden class present (-translate-x-full)" do
    html = render_html(build_component)
    assert_includes html, "-translate-x-full"
  end

  test "desktop visible class present (lg:translate-x-0)" do
    html = render_html(build_component)
    assert_includes html, "lg:translate-x-0"
  end

  test "nav section does NOT have turbo-permanent (active state must update on navigation)" do
    html = render_html(build_component)
    refute_includes html, "data-turbo-permanent"
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
  # Pin button
  # ---------------------------------------------------------------------------

  test "pin button is rendered in footer" do
    html = render_html(build_component)
    assert_includes html, 'data-action="icon-rail#togglePin"'
  end

  test "pin button has correct type" do
    html = render_html(build_component)
    # The button with togglePin action should be type=button
    assert_includes html, 'type="button"'
    assert_includes html, "icon-rail#togglePin"
  end

  test "pin button contains collapse icon span" do
    html = render_html(build_component)
    assert_includes html, "icon-rail-pin-collapse"
  end

  test "pin button contains expand icon span" do
    html = render_html(build_component)
    assert_includes html, "icon-rail-pin-expand"
  end

  # ---------------------------------------------------------------------------
  # Menu item rendering — leaf items
  # ---------------------------------------------------------------------------

  test "renders anchor tags for leaf menu items" do
    items = [
      StubItem.new(label: "Dashboard", url: "/dashboard", icon: nil, items: []),
      StubItem.new(label: "Customers", url: "/customers", icon: nil, items: [])
    ]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, 'href="/dashboard"'
    assert_includes html, 'href="/customers"'
  end

  test "leaf item anchor has title and aria-label matching item label" do
    items = [StubItem.new(label: "Reports", url: "/reports", icon: nil, items: [])]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, 'title="Reports"'
    assert_includes html, 'aria-label="Reports"'
  end

  test "leaf item has icon-rail-leaf class" do
    items = [StubItem.new(label: "Reports", url: "/reports", icon: nil, items: [])]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, "icon-rail-leaf"
  end

  test "leaf item does not produce flyout markup" do
    items = [StubItem.new(label: "Leaf", url: "/leaf", icon: nil, items: [])]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    refute_includes html, "icon-rail-flyout"
    refute_includes html, "icon-rail-children"
  end

  test "leaf item contains hidden label span for pinned mode" do
    items = [StubItem.new(label: "Reports", url: "/reports", icon: nil, items: [])]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, "icon-rail-label"
    assert_includes html, "Reports"
  end

  # ---------------------------------------------------------------------------
  # Menu item rendering — parent items with children
  # ---------------------------------------------------------------------------

  test "parent item produces flyout markup" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    assert_includes html, "icon-rail-flyout"
    assert_includes html, "icon-rail-flyout-inner"
    assert_includes html, "icon-rail-flyout-label"
    assert_includes html, "icon-rail-flyout-item"
  end

  test "parent item wrapper has icon-rail-flyout data-controller" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    assert_includes html, 'data-controller="icon-rail-flyout"'
  end

  test "parent wrapper data-action includes mouseenter open and keydown esc" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    assert_includes html, "mouseenter->icon-rail-flyout#open"
    assert_includes html, "keydown.esc@window->icon-rail-flyout#closeOnEsc"
  end

  test "parent trigger has icon-rail-flyout-target trigger and click toggle action" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    assert_includes html, 'data-icon-rail-flyout-target="trigger"'
    assert_includes html, "click->icon-rail-flyout#toggle"
  end

  test "flyout panel has icon-rail-flyout-target panel" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    assert_includes html, 'data-icon-rail-flyout-target="panel"'
  end

  test "flyout lists child item labels and hrefs" do
    child = StubItem.new(label: "Child Page", url: "/child", icon: nil, items: [])
    parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    assert_includes html, "Child Page"
    assert_includes html, 'href="/child"'
  end

  test "parent trigger is an anchor tag with icon-rail-parent-trigger class" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    parent = StubItem.new(label: "Parent", url: "/parent", icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    assert_includes html, 'href="/parent"'
    assert_includes html, "icon-rail-parent-trigger"
  end

  test "parent trigger falls back to # when no url" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    assert_includes html, 'href="#"'
  end

  test "parent item has no inline children container or resource-collapse wiring" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    refute_includes html, "icon-rail-children"
    refute_includes html, "resource-collapse"
  end

  test "parent item renders chevron span indicating a flyout" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    assert_includes html, "icon-rail-chevron"
  end

  test "child link appears exactly once (only in flyout)" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    assert_equal 1, html.scan('href="/child"').length, "child href should appear exactly once (flyout only)"
  end

  # ---------------------------------------------------------------------------
  # Per-item target / rel options
  # ---------------------------------------------------------------------------

  test "leaf item honors :target and :rel from item options" do
    items = [StubItem.new(label: "Inbox", url: "/inbox", icon: nil, items: [], options: {target: "_blank", rel: "noopener"})]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, 'target="_blank"'
    assert_includes html, 'rel="noopener"'
  end

  test "leaf item omits target/rel when not provided" do
    items = [StubItem.new(label: "Home", url: "/", icon: nil, items: [])]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    refute_includes html, " target="
    refute_includes html, " rel="
  end

  test "flyout child honors :target and :rel from child options" do
    child = StubItem.new(label: "External", url: "/external", icon: nil, items: [], options: {target: "_blank", rel: "noopener"})
    parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    assert_includes html, 'target="_blank"'
    assert_includes html, 'rel="noopener"'
  end

  test "leaf item spreads arbitrary html attributes from options" do
    items = [StubItem.new(label: "Inbox", url: "/inbox", icon: nil, items: [], options: {data: {turbo_frame: "_top"}})]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, 'data-turbo-frame="_top"'
  end

  test "leaf item does not leak Phlexi :active option onto the anchor" do
    items = [StubItem.new(label: "Home", url: "/", icon: nil, items: [], options: {active: ->(_) { true }})]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    refute_includes html, "active="
  end

  test "leaf item merges a custom :class with the base classes" do
    items = [StubItem.new(label: "Home", url: "/", icon: nil, items: [], options: {class: "custom-leaf"})]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, "icon-rail-leaf"
    assert_includes html, "custom-leaf"
  end

  test "parent trigger honors options and keeps its flyout wiring" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    parent = StubItem.new(
      label: "Parent", url: "/parent", icon: nil, items: [child],
      options: {target: "_blank", rel: "noopener", data: {turbo_frame: "_top"}}
    )
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    # User-supplied attributes are honored on the trigger anchor...
    assert_includes html, 'target="_blank"'
    assert_includes html, 'rel="noopener"'
    assert_includes html, 'data-turbo-frame="_top"'
    # ...without clobbering the framework's flyout wiring.
    assert_includes html, 'data-icon-rail-flyout-target="trigger"'
    assert_includes html, "click->icon-rail-flyout#toggle"
    assert_includes html, "icon-rail-parent-trigger"
  end

  test "parent trigger options cannot override the flyout data wiring" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    # Hostile/clumsy option: try to override the toggle action — framework wins.
    parent = StubItem.new(
      label: "Parent", url: nil, icon: nil, items: [child],
      options: {data: {action: "something#else"}}
    )
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    assert_includes html, "click->icon-rail-flyout#toggle"
    refute_includes html, "something#else"
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

  test "active leaf item receives bg-primary-100 class" do
    items = [ActiveStubItem.new(label: "Active Page", url: "/active", icon: nil, items: [])]
    menu = StubMenu.new(items)
    html = render_html(build_component(menu: menu))

    assert_includes html, "bg-primary-100"
    assert_includes html, "text-primary-700"
  end

  test "inactive leaf item does not receive bg-primary-100" do
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

  test "nested child items are rendered in flyout only" do
    child = StubItem.new(label: "Child", url: "/child", icon: nil, items: [])
    parent = StubItem.new(label: "Parent", url: nil, icon: nil, items: [child])
    menu = StubMenu.new([parent])
    html = render_html(build_component(menu: menu))

    assert_includes html, 'href="/child"'
    # Child link appears exactly once: only in flyout (no inline tree)
    assert_equal 1, html.scan('href="/child"').length
  end
end
