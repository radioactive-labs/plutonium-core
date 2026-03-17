# frozen_string_literal: true

require "test_helper"
require "ostruct"
require "pagy"
require "pagy/toolbox/helpers/support/series"
require "plutonium/ui/table/components/pagy_pagination"

class Plutonium::UI::Table::Components::PagyPaginationTest < Minitest::Test
  def test_renders_navigation
    pagy = build_pagy(count: 100, page: 3, limit: 10)
    html = render_component(pagy)

    assert_match(/<nav/, html)
    assert_match(/aria-label="Page navigation"/, html)
  end

  def test_renders_page_numbers
    pagy = build_pagy(count: 50, page: 1, limit: 10)
    html = render_component(pagy)

    # 50 items / 10 per page = 5 pages
    (1..5).each do |page|
      assert_includes html, page.to_s
    end
  end

  def test_first_page_disables_prev_link
    pagy = build_pagy(count: 50, page: 1, limit: 10)
    html = render_component(pagy)

    assert_match(/aria-disabled="true"/, html)
  end

  def test_first_page_enables_next_link
    pagy = build_pagy(count: 50, page: 1, limit: 10)
    html = render_component(pagy)

    assert_match(%r{href="/posts\?page=2"}, html)
  end

  def test_last_page_disables_next_link
    pagy = build_pagy(count: 50, page: 5, limit: 10)
    html = render_component(pagy)

    # Two disabled buttons: next and current page
    assert_match(/aria-disabled="true"/, html)
  end

  def test_last_page_enables_prev_link
    pagy = build_pagy(count: 50, page: 5, limit: 10)
    html = render_component(pagy)

    assert_match(%r{href="/posts\?page=4"}, html)
  end

  def test_middle_page_has_prev_and_next
    pagy = build_pagy(count: 100, page: 5, limit: 10)
    html = render_component(pagy)

    assert_match(%r{href="/posts\?page=4"}, html, "Expected prev link to page 4")
    assert_match(%r{href="/posts\?page=6"}, html, "Expected next link to page 6")
  end

  def test_current_page_shows_as_button_with_aria_current
    pagy = build_pagy(count: 50, page: 3, limit: 10)
    html = render_component(pagy)

    assert_match(/aria-current="page"/, html)
    assert_match(/aria-current="page"[^>]*>3</, html)
  end

  def test_gap_renders_ellipsis
    pagy = build_pagy(count: 500, page: 10, limit: 10)
    html = render_component(pagy)

    assert_includes html, "..."
  end

  def test_single_page_disables_both_nav_buttons
    pagy = build_pagy(count: 5, page: 1, limit: 10)
    html = render_component(pagy)

    disabled_count = html.scan(/aria-disabled="true"/).length
    assert_equal 2, disabled_count, "Expected both prev and next to be disabled"
  end

  private

  def build_pagy(count:, page:, limit:)
    pagy = Pagy::Offset.new(count: count, page: page, limit: limit)
    mock_request = OpenStruct.new(params: {"page" => page.to_s}, path: "/posts")
    pagy.instance_variable_set(:@request, mock_request)
    pagy
  end

  def render_component(pagy)
    component = Plutonium::UI::Table::Components::PagyPagination.new(pagy)
    component.call
  end
end
