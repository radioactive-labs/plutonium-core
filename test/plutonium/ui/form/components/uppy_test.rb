# frozen_string_literal: true

require "test_helper"

# Regression: the uppy uploader previews an already-attached blob both on the
# new/edit form and when phlexi re-renders the form to extract params. The blob's
# `filename` is an ActiveStorage::Filename, and Phlex 2.4 raises on a non-String
# `title:`. Both `render_attachment_preview` and `render_filename` must `.to_s` it.
class Plutonium::UI::Form::Components::UppyTest < ActiveSupport::TestCase
  Component = Plutonium::UI::Form::Components::Uppy

  # ActiveStorage attachment backed by a PERSISTED blob (the direct-upload case).
  def fake_attachment
    blob = Object.new
    blob.define_singleton_method(:new_record?) { false }

    att = Object.new
    att.define_singleton_method(:url) { "/blob/example.jpg" }
    att.define_singleton_method(:filename) { ActiveStorage::Filename.new("example.jpg") }
    att.define_singleton_method(:content_type) { "image/jpeg" }
    att.define_singleton_method(:signed_id) { "signed-id" }
    att.define_singleton_method(:representable?) { false }
    att.define_singleton_method(:try) { |m| (m == :blob) ? blob : nil }
    att
  end

  # ActiveStorage attachment on an UNSAVED record: signed_id delegates to the blob,
  # and a NEW blob raises "Cannot get a signed_id for a new record" (validation
  # re-render / non-JS submit). The form must render instead of blowing up.
  def fake_unpersisted_attachment
    blob = Object.new
    blob.define_singleton_method(:new_record?) { true }
    blob.define_singleton_method(:signed_id) { raise ArgumentError, "Cannot get a signed_id for a new record" }

    att = Object.new
    att.define_singleton_method(:url) { "/blob/pending.jpg" }
    att.define_singleton_method(:filename) { ActiveStorage::Filename.new("pending.jpg") }
    att.define_singleton_method(:content_type) { "image/jpeg" }
    att.define_singleton_method(:representable?) { false }
    att.define_singleton_method(:signed_id) { blob.signed_id }  # delegate_missing_to :blob
    att.define_singleton_method(:try) { |m| (m == :blob) ? blob : nil }
    att
  end

  # active_shrine (and the wizard's Resolved view) sign the file DATA itself, so
  # signed_id works even on an unsaved record — the preview must KEEP the token.
  # There's no blob, so try(:blob) is nil.
  def fake_shrine_attachment
    att = Object.new
    att.define_singleton_method(:url) { "/shrine/doc.pdf" }
    att.define_singleton_method(:filename) { "doc.pdf" }
    att.define_singleton_method(:content_type) { "application/pdf" }
    att.define_singleton_method(:representable?) { false }
    att.define_singleton_method(:signed_id) { "shrine-token" }
    att.define_singleton_method(:try) { |_m| nil }
    att
  end

  # `Plutonium::Attachments::Resolved` (and a Shrine UploadedFile) expose
  # `extension` WITHOUT a leading dot. `try(:extension)` returns that bare value,
  # and the render path must still prepend exactly one dot — never two.
  def fake_attachment_with_extension
    blob = Object.new
    blob.define_singleton_method(:new_record?) { false }

    att = Object.new
    att.define_singleton_method(:url) { "/blob/report.pdf" }
    att.define_singleton_method(:filename) { ActiveStorage::Filename.new("report.pdf") }
    att.define_singleton_method(:content_type) { "application/pdf" }
    att.define_singleton_method(:signed_id) { "signed-id" }
    att.define_singleton_method(:representable?) { false }
    att.define_singleton_method(:try) do |m|
      if m == :extension
        "pdf"
      elsif m == :blob
        blob
      end
    end
    att
  end

  # Drives render_attachment_preview (which calls render_preview_content,
  # render_filename and render_delete_button) with the Phlex DSL stubbed,
  # capturing every `title:` attribute.
  # Returns [titles, hidden_values] captured from the stubbed Phlex DSL.
  def render_preview(attachment)
    component = Component.allocate
    component.instance_variable_set(:@attributes, {name: "post[image]", multiple: false})
    titles = []
    hidden_values = []

    %i[div a span img button input].each do |tag|
      component.define_singleton_method(tag) do |*_args, **attrs, &block|
        titles << attrs[:title] if attrs.key?(:title)
        hidden_values << attrs[:value] if tag == :input && attrs[:type] == :hidden
        block&.call
        nil
      end
    end
    component.define_singleton_method(:plain) { |_text| nil }

    component.send(:render_attachment_preview, attachment)
    [titles, hidden_values]
  end

  # Drives render_attachment_preview with the Phlex DSL stubbed, capturing the
  # text each element's block evaluates to. Only String return values are
  # returned — the captions render through `plain` (stubbed to nil), so the only
  # String that survives is the extension fallback `div` block:
  # `".#{attachment_extension}"`.
  def rendered_text(attachment)
    component = Component.allocate
    component.instance_variable_set(:@attributes, {name: "post[file]", multiple: false})
    texts = []

    %i[div a span img button input].each do |tag|
      component.define_singleton_method(tag) do |*_args, **attrs, &block|
        texts << block&.call if block
        nil
      end
    end
    component.define_singleton_method(:plain) { |_text| nil }

    component.send(:render_attachment_preview, attachment)
    texts.grep(String)
  end

  test "title attributes are plain Strings, not ActiveStorage::Filename" do
    titles, = render_preview(fake_attachment)

    refute_empty titles, "expected the preview to set title attributes"
    titles.each do |title|
      assert_instance_of String, title,
        "title must be a String for Phlex 2.4 attribute validation, got #{title.class}"
    end
    assert_includes titles, "example.jpg"
  end

  test "a persisted attachment preserves its signed_id in a hidden field" do
    _titles, hidden = render_preview(fake_attachment)
    assert_includes hidden, "signed-id",
      "expected the preview to round-trip the blob's signed_id"
  end

  test "an unpersisted ActiveStorage blob does not raise and omits the signed_id field" do
    titles = hidden = nil
    assert_nothing_raised do
      titles, hidden = render_preview(fake_unpersisted_attachment)
    end

    assert_includes titles, "pending.jpg", "the preview still renders"
    assert_empty hidden.compact,
      "no signed_id hidden field when the AS blob is unpersisted (nothing to preserve)"
  end

  test "an active_shrine attachment keeps its signed_id even when unsaved" do
    # Shrine signs the file data, so the token is valid on an unsaved record and
    # MUST survive a re-render — the persisted-parent case must not drop it.
    _titles, hidden = render_preview(fake_shrine_attachment)
    assert_includes hidden, "shrine-token",
      "shrine's signed_id must be preserved (it works without persistence)"
  end

  # Regression (commit 08317d68): same double-dot bug as the Display/Table
  # attachment components, but on the form's uppy preview. A non-representable
  # ActiveStorage/Shrine attachment with no `extension` method falls back to
  # `File.extname` (dot-prefixed), and the render path then prepended another
  # dot → `..pdf`. The fallback must strip the dot so the result is `.pdf`.
  # `fake_shrine_attachment` has filename "doc.pdf" and `try` → nil, exercising
  # the fallback.
  test "extension fallback shows a single dot for non-representable attachments" do
    texts = rendered_text(fake_shrine_attachment)

    assert_includes texts, ".pdf",
      "fallback preview should render '.pdf' (single dot), got #{texts.inspect}"
    texts.each do |text|
      refute text.start_with?(".."),
        "double-dot extension regression: rendered #{text.inspect}"
    end
  end

  # `Plutonium::Attachments::Resolved` and a Shrine UploadedFile expose
  # `extension` WITHOUT a leading dot. `try(:extension)` returns that bare
  # value and the render path must still prepend exactly one dot.
  test "attachment answering #extension (no dot) still renders a single dot" do
    texts = rendered_text(fake_attachment_with_extension)

    assert_includes texts, ".pdf",
      "when #extension returns 'pdf' the render must show '.pdf', got #{texts.inspect}"
    texts.each do |text|
      refute text.start_with?(".."),
        "double-dot extension regression: rendered #{text.inspect}"
    end
  end
end
