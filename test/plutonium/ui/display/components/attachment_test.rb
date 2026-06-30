# frozen_string_literal: true

require "test_helper"

# Regression: ActiveStorage::Blob#filename returns an ActiveStorage::Filename,
# NOT a String. Phlex 2.4 validates attribute values and raises
# Phlex::ArgumentError when a `title:` is handed a non-String. Every filename
# that flows into an HTML attribute (or `plain`) must therefore be coerced with
# `.to_s`.
class Plutonium::UI::Display::Components::AttachmentTest < ActiveSupport::TestCase
  Component = Plutonium::UI::Display::Components::Attachment

  # A faithful stand-in for an attached blob: `filename` returns the real
  # ActiveStorage::Filename object, exactly as the show page sees it.
  def fake_attachment
    att = Object.new
    att.define_singleton_method(:url) { "/blob/example.jpg" }
    att.define_singleton_method(:filename) { ActiveStorage::Filename.new("example.jpg") }
    att.define_singleton_method(:content_type) { "image/jpeg" }
    att.define_singleton_method(:representable?) { false }
    att.define_singleton_method(:try) { |_m| nil }
    att
  end

  # Renders render_value with the Phlex DSL stubbed, capturing every `title:`
  # attribute that reaches an element.
  def render_value(attachment)
    component = Component.allocate
    titles = []

    component.define_singleton_method(:attributes) { {} }

    %i[div a span img].each do |tag|
      component.define_singleton_method(tag) do |*_args, **attrs, &block|
        titles << attrs[:title] if attrs.key?(:title)
        block&.call
        nil
      end
    end
    component.define_singleton_method(:plain) { |_text| nil }
    component.define_singleton_method(:phlexi_render) { |_value, &block| block&.call }

    component.send(:render_value, attachment)
    titles
  end

  test "title attribute is a plain String, not an ActiveStorage::Filename" do
    titles = render_value(fake_attachment)

    refute_empty titles, "expected render_value to set a title attribute"
    titles.each do |title|
      assert_instance_of String, title,
        "title must be a String for Phlex 2.4 attribute validation, got #{title.class}"
    end
    assert_includes titles, "example.jpg"
  end
end
