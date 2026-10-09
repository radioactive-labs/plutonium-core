# frozen_string_literal: true

require "test_helper"

# `has_rich_text` fields used to get the EasyMDE markdown editor, which wrote
# markdown into an HTML column, and a markdown display of Action Text HTML.
class Plutonium::UI::RichTextFieldTest < ActionView::TestCase
  def sink = KitchenSink.new(notes: "<p>Hello <strong>world</strong></p><script>alert(1)</script>")

  test "a rich text field renders Action Text's editor" do
    html = Plutonium::UI::Form::Base.new(sink).field(:notes).component_for(nil).then { |c| render(c) }
    editor = Nokogiri::HTML.fragment(html)

    assert editor.at_css("trix-editor, lexxy-editor"), "expected an Action Text editor, got #{html}"
    assert_equal "kitchen_sink[notes]", editor.at_css("input[type=hidden], lexxy-editor")["name"]
  end

  test "the editor carries the stored content" do
    html = Plutonium::UI::Form::Base.new(sink).field(:notes).component_for(nil).then { |c| render(c) }

    assert_includes CGI.unescapeHTML(html), "<strong>world</strong>"
  end

  test "submitted HTML is extracted as is" do
    component = Plutonium::UI::Form::Base.new(sink).field(:notes).component_for(nil)

    assert_equal({notes: "<p>Hi</p>"}, component.extract_input({notes: "<p>Hi</p>"}))
  end

  test "the show page renders sanitized HTML" do
    html = Plutonium::UI::Display::Base.new(sink).field(:notes).component_for(nil).then { |c| render(c) }

    assert_includes html, "<strong>world</strong>"
    refute_includes html, "<script>"
  end

  test "an empty rich text field renders nothing" do
    html = Plutonium::UI::Display::Base.new(KitchenSink.new).field(:notes).component_for(nil).then { |c| render(c) }

    refute_includes html, "rich_text value"
  end
end
