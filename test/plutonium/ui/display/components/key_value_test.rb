# frozen_string_literal: true

require "test_helper"

# Hash values (hstore columns, or `as: :key_value`) rendered as pretty JSON.
class Plutonium::UI::Display::Components::KeyValueTest < ActiveSupport::TestCase
  def render_field(prefs, tag: :key_value, display: Plutonium::UI::Display::Base)
    display.new(KitchenSink.new(prefs:)).field(:prefs).component_for(tag).call
  end

  def pairs(html)
    Nokogiri::HTML.fragment(html).css("dl > dt, dl > dd").map { |node| node.text.strip }
  end

  test "each pair renders as a term and its value" do
    assert_equal %w[newsletter weekly theme dark], pairs(render_field({"newsletter" => "weekly", "theme" => "dark"}))
  end

  test "hstore renders as key/value pairs" do
    assert_equal %w[newsletter weekly], pairs(render_field({"newsletter" => "weekly"}, tag: :hstore))
  end

  test "a nested value renders as compact JSON" do
    assert_equal ["limits", '{"max":3}'], pairs(render_field({"limits" => {"max" => 3}}))
  end

  test "a nil value renders a dash" do
    assert_equal %w[newsletter —], pairs(render_field({"newsletter" => nil}))
  end

  test "keys and values are escaped" do
    html = render_field({"<b>k</b>" => "<script>x</script>"})

    refute_includes html, "<script>"
    refute_includes html, "<b>"
  end

  test "an empty hash renders nothing" do
    assert_empty pairs(render_field({}))
  end

  test "a table cell renders the pairs too" do
    assert_equal %w[newsletter weekly], pairs(render_field({"newsletter" => "weekly"}, display: Plutonium::UI::Table::Base::Display))
  end

  test "the list is themed" do
    assert_includes render_field({"a" => "b"}), Plutonium::UI::Display::Theme.instance.resolve_theme(:key_value_key)
  end
end
