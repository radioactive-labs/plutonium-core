# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Layout::TopbarTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def build_component(&block)
    component = Plutonium::UI::Layout::Topbar.new
    component.instance_exec(&block) if block
    component
  end

  def render_html(component)
    component.call
  end

  # ---------------------------------------------------------------------------
  # Structure tests
  # ---------------------------------------------------------------------------

  test "renders a nav element" do
    html = render_html(build_component)
    assert_includes html, "<nav"
  end

  test "nav is fixed and positioned at top-0 right-0 left-0" do
    html = render_html(build_component)
    assert_includes html, "fixed"
    assert_includes html, "top-0"
    assert_includes html, "right-0"
    assert_includes html, "left-0"
  end

  test "nav has lg:left-14 offset for IconRail" do
    html = render_html(build_component)
    assert_includes html, "lg:left-14"
  end

  test "nav has h-12 height (48px)" do
    html = render_html(build_component)
    assert_includes html, "h-12"
  end

  test "nav has z-30 stacking context" do
    html = render_html(build_component)
    assert_includes html, "z-30"
  end

  test "nav has surface background and bottom border" do
    html = render_html(build_component)
    assert_includes html, "bg-[var(--pu-surface)]"
    assert_includes html, "border-b"
    assert_includes html, "border-[var(--pu-border)]"
  end

  test "nav has resource-header data-controller" do
    html = render_html(build_component)
    assert_includes html, 'data-controller="resource-header"'
  end

  test "nav has sidebar outlet wired to #sidebar-navigation" do
    html = render_html(build_component)
    assert_includes html, 'data-resource-header-sidebar-outlet="#sidebar-navigation"'
  end

  # ---------------------------------------------------------------------------
  # Hamburger button
  # ---------------------------------------------------------------------------

  test "hamburger button is always present" do
    html = render_html(build_component)
    assert_includes html, "<button"
  end

  test "hamburger button has lg:hidden so it is desktop-hidden" do
    html = render_html(build_component)
    assert_includes html, "lg:hidden"
  end

  test "hamburger button has toggleDrawer data-action" do
    html = render_html(build_component)
    assert_includes html, "resource-header#toggleDrawer"
  end

  test "hamburger open icon has openIcon target" do
    html = render_html(build_component)
    assert_includes html, 'data-resource-header-target="openIcon"'
  end

  test "hamburger close icon has closeIcon target and is hidden by default" do
    html = render_html(build_component)
    assert_includes html, 'data-resource-header-target="closeIcon"'
    # The close icon span carries the hidden class
    assert_match(/data-resource-header-target="closeIcon"[^>]*class="hidden"/, html)
  end

  # ---------------------------------------------------------------------------
  # Empty topbar (no slots)
  # ---------------------------------------------------------------------------

  test "empty topbar renders without error" do
    html = render_html(build_component)
    assert_includes html, "<nav"
  end

  test "empty topbar still renders hamburger" do
    html = render_html(build_component)
    assert_includes html, "<button"
    assert_includes html, "resource-header#toggleDrawer"
  end

  test "empty topbar renders no breadcrumb wrapper" do
    html = render_html(build_component)
    refute_match(/min-w-0 flex-shrink/, html)
  end

  test "empty topbar renders no search wrapper" do
    html = render_html(build_component)
    refute_includes html, "max-w-[360px]"
  end

  test "empty topbar renders no actions wrapper" do
    html = render_html(build_component)
    refute_includes html, "ml-auto flex items-center gap-1.5"
  end

  # ---------------------------------------------------------------------------
  # Breadcrumbs slot
  # ---------------------------------------------------------------------------

  test "breadcrumbs slot content appears in output" do
    component = build_component
    component.with_breadcrumbs { "HOME / SECTION" }
    html = render_html(component)
    assert_includes html, "HOME / SECTION"
  end

  test "breadcrumbs section wrapper renders when slot is filled" do
    component = build_component
    component.with_breadcrumbs { "crumbs" }
    html = render_html(component)
    assert_includes html, "min-w-0"
    assert_includes html, "flex-shrink"
  end

  test "breadcrumbs section absent when slot not filled" do
    html = render_html(build_component)
    refute_includes html, "min-w-0"
  end

  # ---------------------------------------------------------------------------
  # Search slot
  # ---------------------------------------------------------------------------

  test "search slot content appears in output" do
    component = build_component
    component.with_search { "SEARCH_INPUT" }
    html = render_html(component)
    assert_includes html, "SEARCH_INPUT"
  end

  test "search section has max-w-[360px] constraint" do
    component = build_component
    component.with_search { "search" }
    html = render_html(component)
    assert_includes html, "max-w-[360px]"
  end

  test "search section has flex-1 justify-center centering wrapper" do
    component = build_component
    component.with_search { "search" }
    html = render_html(component)
    assert_includes html, "flex-1"
    assert_includes html, "justify-center"
  end

  test "search section absent when slot not filled" do
    html = render_html(build_component)
    refute_includes html, "max-w-[360px]"
  end

  # ---------------------------------------------------------------------------
  # Action slots
  # ---------------------------------------------------------------------------

  test "single action slot content appears in output" do
    component = build_component
    component.with_action { "ACTION_ONE" }
    html = render_html(component)
    assert_includes html, "ACTION_ONE"
  end

  test "multiple action slots all render in order" do
    component = build_component
    component.with_action { "FIRST" }
    component.with_action { "SECOND" }
    component.with_action { "THIRD" }
    html = render_html(component)

    assert_includes html, "FIRST"
    assert_includes html, "SECOND"
    assert_includes html, "THIRD"

    # Verify order: FIRST appears before SECOND, SECOND before THIRD
    assert html.index("FIRST") < html.index("SECOND")
    assert html.index("SECOND") < html.index("THIRD")
  end

  test "actions wrapper has ml-auto to push it to the right" do
    component = build_component
    component.with_action { "btn" }
    html = render_html(component)
    assert_includes html, "ml-auto"
  end

  test "actions section absent when no action slots filled" do
    html = render_html(build_component)
    refute_includes html, "ml-auto flex items-center gap-1.5"
  end

  # ---------------------------------------------------------------------------
  # Actions align right even when search is absent
  # ---------------------------------------------------------------------------

  test "actions section still has ml-auto when search slot is absent" do
    component = build_component
    component.with_action { "ICON_BTN" }
    html = render_html(component)
    assert_includes html, "ml-auto"
    refute_includes html, "max-w-[360px]"
  end

  # ---------------------------------------------------------------------------
  # Combined slots
  # ---------------------------------------------------------------------------

  test "breadcrumbs, search, and actions all render together" do
    component = build_component
    component.with_breadcrumbs { "BREADCRUMB" }
    component.with_search { "SEARCH" }
    component.with_action { "ACTION" }
    html = render_html(component)

    assert_includes html, "BREADCRUMB"
    assert_includes html, "SEARCH"
    assert_includes html, "ACTION"
    assert_includes html, "max-w-[360px]"
    assert_includes html, "ml-auto"
  end
end
