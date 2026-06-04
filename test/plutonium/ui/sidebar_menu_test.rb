# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::SidebarMenuTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Minimal stand-in for a Phlexi::Menu::Item. `options` mirrors the real
  # Item#options hash (extra kwargs like :target / :rel).
  StubItem = Struct.new(:label, :url, :icon, :items, :leading_badge, :trailing_badge, :options, keyword_init: true) do
    def active?(*)
      false
    end
  end

  StubMenu = Struct.new(:items)

  def build_component(menu)
    Plutonium::UI::SidebarMenu.new(menu)
  end

  def render_html(component)
    component.call
  end

  # ---------------------------------------------------------------------------
  # Classic shell (default)
  # ---------------------------------------------------------------------------

  test "renders a nav element" do
    menu = StubMenu.new([StubItem.new(label: "Home", url: "/", icon: nil, items: [])])
    html = render_html(build_component(menu))
    assert_includes html, "<nav"
  end

  test "renders labelled links" do
    menu = StubMenu.new([StubItem.new(label: "Dashboard", url: "/dashboard", icon: nil, items: [])])
    html = render_html(build_component(menu))
    assert_includes html, "Dashboard"
    assert_includes html, 'href="/dashboard"'
  end

  test "does not render icon-rail markup" do
    menu = StubMenu.new([StubItem.new(label: "Home", url: "/", icon: nil, items: [])])
    html = render_html(build_component(menu))
    refute_includes html, "icon-rail-leaf"
    refute_includes html, "icon-rail-parent"
    refute_includes html, "icon-rail-flyout"
  end

  test "leaf link honors :target and :rel from item options" do
    menu = StubMenu.new([
      StubItem.new(label: "Inbox", url: "/inbox", icon: nil, items: [], options: {target: "_blank", rel: "noopener"})
    ])
    html = render_html(build_component(menu))
    assert_includes html, 'target="_blank"'
    assert_includes html, 'rel="noopener"'
  end

  test "leaf link omits target/rel when not provided" do
    menu = StubMenu.new([StubItem.new(label: "Home", url: "/", icon: nil, items: [])])
    html = render_html(build_component(menu))
    refute_includes html, " target="
    refute_includes html, " rel="
  end

  test "leaf link spreads arbitrary html attributes from options" do
    menu = StubMenu.new([
      StubItem.new(label: "Inbox", url: "/inbox", icon: nil, items: [], options: {data: {turbo_frame: "_top"}})
    ])
    html = render_html(build_component(menu))
    assert_includes html, 'data-turbo-frame="_top"'
  end

  test "leaf link does not leak Phlexi :active option onto the anchor" do
    menu = StubMenu.new([
      StubItem.new(label: "Home", url: "/", icon: nil, items: [], options: {active: ->(_) { true }})
    ])
    html = render_html(build_component(menu))
    refute_includes html, "active="
  end
end
