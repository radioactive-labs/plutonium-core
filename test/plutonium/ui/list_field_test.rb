# frozen_string_literal: true

require "test_helper"

# `as: :list`: an array value edited as chips (slim-select, multiple, values
# can be typed in) and shown as chips.
class Plutonium::UI::ListFieldTest < ActiveSupport::TestCase
  def sink(nicknames = %w[Sinky Basin]) = KitchenSink.new(nicknames:)

  def input(record = sink, **attributes) = Plutonium::UI::Form::Base.new(record).field(:nicknames).component_for(:list, **attributes)

  def select_node(html) = Nokogiri::HTML.fragment(html).at_css("select")

  test "the input is a multi-select chip input that accepts typed values" do
    select = select_node(input.call)

    assert select["multiple"]
    assert_equal "kitchen_sink[nicknames][]", select["name"]
    assert_includes select["data-controller"], "slim-select"
    assert_equal "true", select["data-slim-select-addable-value"]
  end

  test "the current values are selected" do
    assert_equal %w[Sinky Basin], select_node(input.call).css("option[selected]").map(&:text)
  end

  test "suggestions are offered without being selected" do
    select = select_node(input(suggestions: %w[Tub Basin]).call)

    assert_equal %w[Sinky Basin Tub], select.css("option").map(&:text).reject(&:empty?)
    assert_equal %w[Sinky Basin], select.css("option[selected]").map(&:text)
  end

  test "limit caps the number of chips" do
    assert_equal "3", select_node(input(limit: 3).call)["data-slim-select-max-selected-value"]
  end

  test "addable: false only allows picking suggestions" do
    assert_nil select_node(input(addable: false).call)["data-slim-select-addable-value"]
  end

  test "submitted values come back as an array" do
    assert_equal({nicknames: %w[Tub Basin]}, input.extract_input({nicknames: ["", "Tub", "Basin"]}))
  end

  test "submitting no chips clears the list" do
    assert_equal({nicknames: []}, input.extract_input({nicknames: [""]}))
  end

  def display(record = sink, display: Plutonium::UI::Display::Base)
    display.new(record).field(:nicknames).component_for(:list).call
  end

  def chips(html) = Nokogiri::HTML.fragment(html).css("li").map { |node| node.text.strip }

  test "the show page renders each item as a chip" do
    assert_equal %w[Sinky Basin], chips(display)
  end

  test "the items share one list" do
    assert_equal 1, Nokogiri::HTML.fragment(display).css("ul").size
  end

  test "a table cell renders chips too" do
    assert_equal %w[Sinky Basin], chips(display(display: Plutonium::UI::Table::Base::Display))
  end

  test "items are escaped" do
    refute_includes display(sink(["<script>x</script>"])), "<script>"
  end

  test "an empty list renders nothing" do
    assert_empty chips(display(sink([])))
  end
end
