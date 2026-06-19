# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Modal::CenteredTest < ActiveSupport::TestCase
  def render_html(component, &block)
    component.call(&block)
  end

  test "renders a dialog element" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    assert_includes html, "<dialog"
  end

  test "dialog has remote-modal data-controller" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    assert_includes html, 'data-controller="remote-modal"'
  end

  test "dialog has closedby=any attribute" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    assert_includes html, 'closedby="any"'
  end

  test "dialog has centered positioning classes" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    assert_includes html, "items-center"
    assert_includes html, "justify-center"
  end

  test "dialog is transform-free (no containing block for fixed children)" do
    # A transformed <dialog> becomes the containing block for its
    # position:fixed descendants, trapping fixed UI (uppy's upload overlay,
    # teleported dropdowns) inside the panel box. Centering must be
    # flex-based, not translate-based.
    html = render_html(Plutonium::UI::Modal::Centered.new)
    refute_includes html, "top-1/2"
    refute_includes html, "-translate-y-1/2"
    refute_includes html, "-translate-x-1/2"
  end

  test "panel has max-h-[80vh] class" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    assert_includes html, "max-h-[80vh]"
  end

  test "panel carries the open/close scale animation via group-data-[open]" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    assert_includes html, "scale-95"
    assert_includes html, "group-data-[open]:scale-100"
  end

  test "renders title in header when provided" do
    html = render_html(Plutonium::UI::Modal::Centered.new(title: "My Title"))
    assert_includes html, "My Title"
    assert_includes html, "<h2"
  end

  test "does not render h2 when title is nil" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    refute_includes html, "<h2"
  end

  test "renders description when provided" do
    html = render_html(Plutonium::UI::Modal::Centered.new(description: "My description"))
    assert_includes html, "My description"
    assert_includes html, "<p"
  end

  test "renders default close button with remote-modal#close action" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    assert_includes html, 'data-action="remote-modal#close"'
  end

  test "close button has correct aria-label" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    assert_includes html, 'aria-label="Close dialog"'
  end

  test "renders body content from block" do
    html = render_html(Plutonium::UI::Modal::Centered.new) do
      "BODY_CONTENT"
    end
    assert_includes html, "BODY_CONTENT"
  end

  test "does not render footer when footer slot not set" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    # No border-t separator (footer div class)
    refute_includes html, "border-t border-[var(--pu-border)]"
  end

  test "renders footer when footer slot is set" do
    component = Plutonium::UI::Modal::Centered.new
    component.with_footer { "Footer content" }
    html = render_html(component)
    assert_includes html, "border-t border-[var(--pu-border)]"
    assert_includes html, "Footer content"
  end

  test "renders panel with surface + flex column layout" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    assert_includes html, "pu-dialog"
    assert_includes html, "flex flex-col min-h-0"
  end

  test "size defaults to :md" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    assert_includes html, Plutonium::UI::Modal::Centered::SIZE_CLASSES.fetch(:md)
  end

  test "size: dispatches into SIZE_CLASSES" do
    Plutonium::UI::Modal::Centered::SIZE_CLASSES.each do |size, classes|
      html = render_html(Plutonium::UI::Modal::Centered.new(size: size))
      assert_includes html, classes, "expected size :#{size} to render #{classes.inspect}"
    end
  end

  test "invalid size: raises ArgumentError" do
    error = assert_raises(ArgumentError) { Plutonium::UI::Modal::Centered.new(size: :huge) }
    assert_match(/modal size must be one of/, error.message)
  end
end
