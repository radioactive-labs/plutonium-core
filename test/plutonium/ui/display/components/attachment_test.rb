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

  # Renders render_value with the Phlex DSL stubbed, capturing the text each
  # element's block evaluates to. Only String return values are returned — the
  # caption renders through `plain` (stubbed to nil), so the only String that
  # survives is the extension fallback `div` block: `".#{attachment_extension}"`.
  def rendered_text(attachment)
    component = Component.allocate
    texts = []

    component.define_singleton_method(:attributes) { {} }

    %i[div a span img].each do |tag|
      component.define_singleton_method(tag) do |*_args, **attrs, &block|
        texts << block&.call if block
        nil
      end
    end
    component.define_singleton_method(:plain) { |_text| nil }
    component.define_singleton_method(:phlexi_render) { |_value, &block| block&.call }

    component.send(:render_value, attachment)
    texts.grep(String)
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

  # Regression (commit 08317d68): for a non-representable ActiveStorage attachment
  # `try(:extension)` is nil (ActiveStorage::Attached::One → Blob → none, no
  # `extension` method), so the helper falls back to `File.extname` — which
  # returns the extension WITH a leading dot. The render path then prepended
  # another dot, producing `..pdf` instead of `.pdf`. The fallback must strip
  # the dot so the result is `.pdf`.
  test "extension fallback shows a single dot for non-representable ActiveStorage attachments" do
    att = Object.new
    att.define_singleton_method(:url) { "/blob/report.pdf" }
    att.define_singleton_method(:filename) { ActiveStorage::Filename.new("report.pdf") }
    att.define_singleton_method(:content_type) { "application/pdf" }
    att.define_singleton_method(:representable?) { false }
    att.define_singleton_method(:try) { |_m| nil }

    texts = rendered_text(att)

    assert_includes texts, ".pdf",
      "fallback thumbnail should render '.pdf' (single dot), got #{texts.inspect}"
    texts.each do |text|
      refute text.start_with?(".."),
        "double-dot extension regression: rendered #{text.inspect}"
    end
  end

  # `Plutonium::Attachments::Resolved` (and a Shrine UploadedFile) expose
  # `extension` WITHOUT a leading dot (e.g. "pdf"). `try(:extension)` returns
  # that bare value, and the render path must still prepend exactly one dot —
  # never zero, never two.
  test "attachment answering #extension (no dot) still renders a single dot" do
    att = Object.new
    att.define_singleton_method(:url) { "/blob/report.pdf" }
    att.define_singleton_method(:filename) { ActiveStorage::Filename.new("report.pdf") }
    att.define_singleton_method(:content_type) { "application/pdf" }
    att.define_singleton_method(:representable?) { false }
    att.define_singleton_method(:try) { |m| (m == :extension) ? "pdf" : nil }

    texts = rendered_text(att)

    assert_includes texts, ".pdf",
      "when #extension returns 'pdf' the render must show '.pdf', got #{texts.inspect}"
    texts.each do |text|
      refute text.start_with?(".."),
        "double-dot extension regression: rendered #{text.inspect}"
    end
  end
end
