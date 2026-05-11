# frozen_string_literal: true

require "test_helper"
require "plutonium/ui/table/components/view_switcher"
require "plutonium/ui/table/components/toolbar"

# ---------------------------------------------------------------------------
# ViewSwitcher
# ---------------------------------------------------------------------------

class Plutonium::UI::Table::Components::ViewSwitcherTest < Minitest::Test
  def test_renders_a_segment_per_view
    html = render_switcher(views: [:table, :grid], current: :table)
    assert_equal 2, html.scan("<button").length
  end

  def test_marks_current_segment_active
    html = render_switcher(views: [:table, :grid], current: :grid)
    # The active segment carries the bg-primary-50 class.
    assert_match(/bg-primary-50/, html)
    assert_match(/aria-selected="true"/, html)
  end

  def test_renders_tablist_role
    html = render_switcher(views: [:table, :grid], current: :table)
    assert_match(/role="tablist"/, html)
  end

  def test_renders_tab_role_on_each_segment
    html = render_switcher(views: [:table, :grid], current: :table)
    assert_equal 2, html.scan('role="tab"').length
  end

  def test_does_not_render_when_only_one_view
    component = build_switcher(views: [:table], current: :table)
    refute component.render?
  end

  def test_writes_cookie_name_value_on_root
    html = render_switcher(views: [:table, :grid], current: :table, cookie_name: "pu_view_post")
    assert_match(/data-view-switcher-cookie-name-value="pu_view_post"/, html)
  end

  def test_writes_cookie_path_value_on_root
    html = render_switcher(views: [:table, :grid], current: :table, cookie_path: "/admin")
    assert_match(/data-view-switcher-cookie-path-value="\/admin"/, html)
  end

  private

  def build_switcher(views:, current:, cookie_name: "pu_view", cookie_path: "/")
    Plutonium::UI::Table::Components::ViewSwitcher.new(
      views: views, current: current, cookie_name: cookie_name, cookie_path: cookie_path
    )
  end

  def render_switcher(**)
    build_switcher(**).call
  end
end

# ---------------------------------------------------------------------------
# Toolbar
# ---------------------------------------------------------------------------

class Plutonium::UI::Table::Components::ToolbarTest < Minitest::Test
  SEARCH_URL = "/posts"

  def test_does_not_render_with_single_view_and_no_query
    component = build_toolbar(views: [:table], query: nil)
    refute component.render?
  end

  def test_renders_when_multiple_views
    component = build_toolbar(views: [:table, :grid], query: nil)
    assert component.render?
  end

  def test_renders_when_query_has_filters
    component = build_toolbar(views: [:table], query: stub_query(filters: true))
    assert component.render?
  end

  def test_renders_when_query_has_search
    component = build_toolbar(views: [:table], query: stub_query(search: true))
    assert component.render?
  end

  def test_renders_view_switcher_when_multiple_views
    html = render_toolbar(views: [:table, :grid])
    assert_match(/role="tablist"/, html)
  end

  def test_renders_filter_button_when_filters_present
    html = render_toolbar(query: stub_query(filters: true))
    assert_match(/Filter/, html)
    assert_match(/filter-panel#toggle/, html)
  end

  def test_does_not_render_filter_button_without_filters
    html = render_toolbar(views: [:table, :grid])
    refute_match(/filter-panel#toggle/, html)
  end

  def test_search_input_has_correct_name
    html = render_toolbar(query: stub_query(search: true))
    assert_match(/name="q\[search\]"/, html)
  end

  def test_search_form_submits_to_search_url
    html = render_toolbar(query: stub_query(search: true))
    assert_match(/action="\/posts"/, html)
  end

  def test_search_input_echoes_search_value
    html = render_toolbar(query: stub_query(search: true), search_value: "hello world")
    assert_match(/value="hello world"/, html)
  end

  def test_search_input_uses_custom_search_param
    html = render_toolbar(query: stub_query(search: true), search_param: :filter)
    assert_match(/name="filter\[search\]"/, html)
  end

  def test_search_form_uses_get_method
    html = render_toolbar(query: stub_query(search: true))
    assert_match(/method="get"/, html)
  end

  def test_search_input_is_type_search
    html = render_toolbar(query: stub_query(search: true))
    assert_match(/type="search"/, html)
  end

  private

  def build_toolbar(views: [:table, :grid], query: nil, search_value: nil, search_param: :q)
    Plutonium::UI::Table::Components::Toolbar.new(
      query: query,
      search_url: SEARCH_URL,
      search_param: search_param,
      search_value: search_value,
      views: views,
      current_view: views.first
    )
  end

  def render_toolbar(**)
    build_toolbar(**).call
  end

  def stub_query(filters: false, search: false, descriptions: [])
    Struct.new(:filter_definitions, :search_filter, :active_filter_descriptions).new(
      filters ? {a: :b} : nil,
      search ? :search_filter : nil,
      descriptions
    )
  end
end
