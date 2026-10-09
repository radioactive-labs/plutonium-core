# frozen_string_literal: true

require "test_helper"

# Opt-in display types: relative_time, code, duration, file_size, progress,
# rating. Each reads an existing KitchenSink column through `as:`.
class Plutonium::UI::Display::Components::ValueTypesTest < ActiveSupport::TestCase
  def render_display(key, tag, display: Plutonium::UI::Display::Base, **values)
    record = KitchenSink.new(**values)
    Nokogiri::HTML.fragment(display.new(record).field(key).component_for(tag).call)
  end

  # relative_time

  test "relative_time renders a live timeago element with the absolute time as fallback" do
    at = Time.utc(2026, 1, 2, 3, 4, 5)
    node = render_display(:meeting_at, :relative_time, meeting_at: at).at_css("time")

    assert_equal "timeago", node["data-controller"]
    assert_equal at.iso8601, node["datetime"]
    assert_equal I18n.l(at, format: :long), node.text.strip
    assert_equal node.text.strip, node["title"]
  end

  # code

  test "code renders the value in monospace with a copy button" do
    html = render_display(:tracking_id, :code, tracking_id: "trk_9f2")

    assert_equal "trk_9f2", html.at_css("code[data-clipboard-target='source']").text
    assert_equal "clipboard#copy", html.at_css("button")["data-action"]
    assert html.at_css("[data-controller='clipboard']")
  end

  # duration

  test "duration formats seconds into compact units" do
    assert_equal "2h 15m", render_display(:age, :duration, age: 8100).text.strip
    assert_equal "1d 1h 1m 1s", render_display(:age, :duration, age: 90_061).text.strip
  end

  test "duration of zero reads 0s" do
    assert_equal "0s", render_display(:age, :duration, age: 0).text.strip
  end

  # file_size

  test "file_size renders bytes as a human size" do
    assert_equal "12 KB", render_display(:age, :file_size, age: 12_288).text.strip
  end

  # progress

  test "progress renders an accessible bar at the value's percentage" do
    html = render_display(:age, :progress, age: 42)
    bar = html.at_css("[role=progressbar]")

    assert_equal "42", bar["aria-valuenow"]
    assert_includes html.to_html, "width: 42%"
    assert_includes html.text, "42%"
  end

  test "progress clamps out-of-range values" do
    assert_includes render_display(:age, :progress, age: 250).to_html, "width: 100%"
  end

  # rating

  test "rating renders filled stars out of five" do
    html = render_display(:age, :rating, age: 3)

    assert_equal 3, html.css("[data-rating-star='filled']").size
    assert_equal 2, html.css("[data-rating-star='empty']").size
    assert_equal "3 out of 5", html.at_css("[role=img]")["aria-label"]
  end

  test "every new display type is themed in table cells" do
    %i[relative_time code duration file_size progress rating].each do |key|
      assert Plutonium::UI::Table::DisplayTheme.theme.key?(key), "table theme has no #{key}"
    end
  end
end
