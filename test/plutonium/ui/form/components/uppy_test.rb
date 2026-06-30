# frozen_string_literal: true

require "test_helper"

# Regression: the uppy uploader previews an already-attached blob both on the
# new/edit form and when phlexi re-renders the form to extract params. The blob's
# `filename` is an ActiveStorage::Filename, and Phlex 2.4 raises on a non-String
# `title:`. Both `render_attachment_preview` and `render_filename` must `.to_s` it.
class Plutonium::UI::Form::Components::UppyTest < ActiveSupport::TestCase
  Component = Plutonium::UI::Form::Components::Uppy

  def fake_attachment
    att = Object.new
    att.define_singleton_method(:url) { "/blob/example.jpg" }
    att.define_singleton_method(:filename) { ActiveStorage::Filename.new("example.jpg") }
    att.define_singleton_method(:content_type) { "image/jpeg" }
    att.define_singleton_method(:signed_id) { "signed-id" }
    att.define_singleton_method(:representable?) { false }
    att.define_singleton_method(:try) { |_m| nil }
    att
  end

  # Drives render_attachment_preview (which calls render_preview_content,
  # render_filename and render_delete_button) with the Phlex DSL stubbed,
  # capturing every `title:` attribute.
  def render_preview(attachment)
    component = Component.allocate
    component.instance_variable_set(:@attributes, {name: "post[image]", multiple: false})
    titles = []

    %i[div a span img button input].each do |tag|
      component.define_singleton_method(tag) do |*_args, **attrs, &block|
        titles << attrs[:title] if attrs.key?(:title)
        block&.call
        nil
      end
    end
    component.define_singleton_method(:plain) { |_text| nil }

    component.send(:render_attachment_preview, attachment)
    titles
  end

  test "title attributes are plain Strings, not ActiveStorage::Filename" do
    titles = render_preview(fake_attachment)

    refute_empty titles, "expected the preview to set title attributes"
    titles.each do |title|
      assert_instance_of String, title,
        "title must be a String for Phlex 2.4 attribute validation, got #{title.class}"
    end
    assert_includes titles, "example.jpg"
  end
end
