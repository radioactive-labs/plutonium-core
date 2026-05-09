# frozen_string_literal: true

require "test_helper"
require "plutonium/ui/table/components/view_switcher"
require "plutonium/ui/table/components/toolbar"

# ---------------------------------------------------------------------------
# ViewSwitcher tests
# ---------------------------------------------------------------------------

class Plutonium::UI::Table::Components::ViewSwitcherTest < Minitest::Test
  def test_renders_three_segments
    html = build_view_switcher.call
    assert_equal 3, html.scan("<button").length
  end

  def test_grid_segment_is_active_by_default
    html = build_view_switcher.call
    # Phlex renders boolean true as the attribute name with no value
    assert_match(/aria-selected[^>]*>.*?Grid/m, html)
  end

  def test_grid_segment_has_active_classes
    html = build_view_switcher.call
    assert_match(/bg-primary-50/, html)
  end

  def test_cards_segment_is_disabled
    html = build_view_switcher.call
    # Find the Cards button — it should have disabled attribute
    assert_match(/disabled[^>]*>.*?Cards/m, html)
  end

  def test_kanban_segment_is_disabled
    html = build_view_switcher.call
    assert_match(/disabled[^>]*>.*?Kanban/m, html)
  end

  def test_cards_segment_has_coming_soon_title
    html = build_view_switcher.call
    assert_match(/title="Cards — Coming soon"/, html)
  end

  def test_kanban_segment_has_coming_soon_title
    html = build_view_switcher.call
    assert_match(/title="Kanban — Coming soon"/, html)
  end

  def test_grid_segment_has_no_coming_soon_in_title
    html = build_view_switcher.call
    assert_match(/title="Grid"/, html)
  end

  def test_disabled_segments_do_not_have_active_aria_selected
    html = build_view_switcher.call
    # Only the active (Grid) button has aria-selected; disabled segments omit it
    # Phlex renders boolean false by omitting the attribute entirely
    selected_count = html.scan("aria-selected").length
    assert_equal 1, selected_count, "Only 1 segment (Grid) should have aria-selected"
  end

  def test_renders_tablist_role
    html = build_view_switcher.call
    assert_match(/role="tablist"/, html)
  end

  def test_renders_tab_role_on_each_segment
    html = build_view_switcher.call
    assert_equal 3, html.scan('role="tab"').length
  end

  private

  def build_view_switcher
    Plutonium::UI::Table::Components::ViewSwitcher.new
  end
end

# ---------------------------------------------------------------------------
# Toolbar tests
# ---------------------------------------------------------------------------

class Plutonium::UI::Table::Components::ToolbarTest < Minitest::Test
  SEARCH_URL = "/posts"

  def test_renders_view_switcher
    html = render_toolbar
    assert_match(/role="tablist"/, html)
  end

  def test_renders_filter_button_with_icon
    html = render_toolbar
    assert_match(/Filter/, html)
    # filter-panel Stimulus action present
    assert_match(/filter-panel#toggle/, html)
  end

  def test_renders_group_button_disabled
    html = render_toolbar
    assert_match(/Group/, html)
    # The group button is a disabled placeholder
    assert_match(/Group.*Coming soon|Coming soon.*Group/m, html)
  end

  def test_search_input_has_correct_name
    html = render_toolbar
    assert_match(/name="q\[search\]"/, html)
  end

  def test_search_form_submits_to_search_url
    html = render_toolbar
    assert_match(/action="\/posts"/, html)
  end

  def test_search_input_echoes_search_value
    html = render_toolbar(search_value: "hello world")
    assert_match(/value="hello world"/, html)
  end

  def test_search_input_uses_custom_search_param
    html = render_toolbar(search_param: :filter)
    assert_match(/name="filter\[search\]"/, html)
  end

  def test_search_form_uses_get_method
    html = render_toolbar
    assert_match(/method="get"/, html)
  end

  def test_column_config_button_is_disabled
    html = render_toolbar
    assert_match(/aria-label="Configure columns"/, html)
    # The wrapper button should carry disabled
    assert_match(/Configure columns.*disabled|disabled.*Configure columns/m, html)
  end

  def test_overflow_button_is_disabled
    html = render_toolbar
    assert_match(/aria-label="More options"/, html)
    assert_match(/More options.*disabled|disabled.*More options/m, html)
  end

  def test_element_order_view_switcher_before_filter
    html = render_toolbar
    switcher_pos = html.index('role="tablist"')
    filter_pos = html.index("Filter")
    assert switcher_pos < filter_pos, "ViewSwitcher should appear before Filter button"
  end

  def test_element_order_filter_before_search
    html = render_toolbar
    filter_pos = html.index("Filter")
    search_pos = html.index('name="q[search]"')
    assert filter_pos < search_pos, "Filter button should appear before search input"
  end

  def test_element_order_search_before_column_config
    html = render_toolbar
    search_pos = html.index('name="q[search]"')
    column_pos = html.index("Configure columns")
    assert search_pos < column_pos, "Search should appear before column config"
  end

  def test_element_order_column_config_before_overflow
    html = render_toolbar
    column_pos = html.index("Configure columns")
    overflow_pos = html.index("More options")
    assert column_pos < overflow_pos, "Column config should appear before overflow"
  end

  def test_search_input_is_type_search
    html = render_toolbar
    assert_match(/type="search"/, html)
  end

  def test_renders_two_vertical_dividers
    html = render_toolbar
    # The divider is a w-px div
    assert_operator html.scan("w-px").length, :>=, 2
  end

  private

  def render_toolbar(search_value: nil, search_param: :q)
    component = Plutonium::UI::Table::Components::Toolbar.new(
      query: nil,
      search_url: SEARCH_URL,
      search_param: search_param,
      search_value: search_value
    )
    component.call
  end
end
