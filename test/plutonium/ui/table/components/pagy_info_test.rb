# frozen_string_literal: true

require "test_helper"
require "ostruct"
require "pagy"
require "pagy/toolbox/helpers/support/series"
require "plutonium/ui/table/components/pagy_info"

class Plutonium::UI::Table::Components::PagyInfoTest < Minitest::Test
  def test_renders_results_info
    pagy = build_pagy(count: 100, page: 2, limit: 10)
    html = render_component(pagy)

    assert_includes html, "Showing"
    assert_includes html, "11"   # from
    assert_includes html, "20"   # to
    assert_includes html, "100"  # count
    assert_includes html, "results"
  end

  def test_renders_first_page_info
    pagy = build_pagy(count: 50, page: 1, limit: 10)
    html = render_component(pagy)

    assert_includes html, "1"   # from
    assert_includes html, "10"  # to
    assert_includes html, "50"  # count
  end

  def test_renders_last_page_info
    pagy = build_pagy(count: 25, page: 3, limit: 10)
    html = render_component(pagy)

    assert_includes html, "21"  # from
    assert_includes html, "25"  # to
    assert_includes html, "25"  # count
  end

  def test_renders_per_page_selector
    pagy = build_pagy(count: 100, page: 1, limit: 10)
    html = render_component(pagy)

    assert_includes html, "Per page"
    assert_match(/<select/, html)
  end

  def test_per_page_options_include_defaults_and_current
    pagy = build_pagy(count: 100, page: 1, limit: 15)
    html = render_component(pagy)

    # Default options are [5, 10, 20, 50, 100], current limit (15) should be added
    [5, 10, 15, 20, 50, 100].each do |option|
      assert_match(/>#{option}<\/option>/, html, "Expected per-page option #{option}")
    end
  end

  def test_current_limit_is_selected
    pagy = build_pagy(count: 100, page: 1, limit: 20)
    html = render_component(pagy)

    assert_match(/selected.*>20<\/option>/, html)
  end

  def test_per_page_options_generate_urls
    pagy = build_pagy(count: 100, page: 1, limit: 10)
    html = render_component(pagy)

    assert_match(/value="\/posts\?/, html, "Expected per-page option to have a URL value")
  end

  def test_per_page_selector_has_stimulus_controller
    pagy = build_pagy(count: 100, page: 1, limit: 10)
    html = render_component(pagy)

    assert_match(/data-controller="select-navigator"/, html)
    assert_match(/data-action="change->select-navigator#navigate"/, html)
  end

  private

  def build_pagy(count:, page:, limit:)
    pagy = Pagy::Offset.new(count: count, page: page, limit: limit)
    mock_request = OpenStruct.new(params: {"page" => page.to_s}, path: "/posts")
    pagy.instance_variable_set(:@request, mock_request)
    pagy
  end

  def render_component(pagy)
    component = Plutonium::UI::Table::Components::PagyInfo.new(pagy)
    component.call
  end
end
