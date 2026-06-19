# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Modal::SlideoverTest < ActiveSupport::TestCase
  def render_html(component, &block)
    component.call(&block)
  end

  test "renders a dialog element" do
    html = render_html(Plutonium::UI::Modal::Slideover.new)
    assert_includes html, "<dialog"
  end

  test "dialog has remote-modal data-controller" do
    html = render_html(Plutonium::UI::Modal::Slideover.new)
    assert_includes html, 'data-controller="remote-modal"'
  end

  test "dialog has closedby=any attribute" do
    html = render_html(Plutonium::UI::Modal::Slideover.new)
    assert_includes html, 'closedby="any"'
  end

  test "pins the panel to the right edge via flex" do
    html = render_html(Plutonium::UI::Modal::Slideover.new)
    assert_includes html, "justify-end"
    assert_includes html, "inset-0"
  end

  test "dialog is a transparent, transform-free container" do
    # The dialog only positions + dims; the surface and the slide live on
    # the inner panel. `bg-transparent` is unique to the container-dialog
    # — its presence means the dialog carries no surface/transform, so
    # fixed UI opened inside the modal isn't trapped in a transformed box.
    html = render_html(Plutonium::UI::Modal::Slideover.new)
    assert_includes html, "bg-transparent"
  end

  test "panel has responsive width class" do
    html = render_html(Plutonium::UI::Modal::Slideover.new)
    assert_includes html, "sm:w-[480px]"
  end

  test "panel carries the slide-in transition via group-data-[open]" do
    html = render_html(Plutonium::UI::Modal::Slideover.new)
    assert_includes html, "translate-x-full"
    assert_includes html, "group-data-[open]:translate-x-0"
  end

  test "renders title in header when provided" do
    html = render_html(Plutonium::UI::Modal::Slideover.new(title: "Slide Title"))
    assert_includes html, "Slide Title"
    assert_includes html, "<h2"
  end

  test "renders description when provided" do
    html = render_html(Plutonium::UI::Modal::Slideover.new(description: "Slide description"))
    assert_includes html, "Slide description"
  end

  test "renders default close button with remote-modal#close action" do
    html = render_html(Plutonium::UI::Modal::Slideover.new)
    assert_includes html, 'data-action="remote-modal#close"'
  end

  test "close button has correct aria-label" do
    html = render_html(Plutonium::UI::Modal::Slideover.new)
    assert_includes html, 'aria-label="Close dialog"'
  end

  test "renders body content from block" do
    html = render_html(Plutonium::UI::Modal::Slideover.new) do
      "SLIDE_BODY"
    end
    assert_includes html, "SLIDE_BODY"
  end

  test "does not render footer when footer slot not set" do
    html = render_html(Plutonium::UI::Modal::Slideover.new)
    refute_includes html, "border-t border-[var(--pu-border)]"
  end

  test "renders footer when footer slot is set" do
    component = Plutonium::UI::Modal::Slideover.new
    component.with_footer { "Slide Footer" }
    html = render_html(component)
    assert_includes html, "border-t border-[var(--pu-border)]"
    assert_includes html, "Slide Footer"
  end

  test "renders panel with surface + flex column layout" do
    html = render_html(Plutonium::UI::Modal::Slideover.new)
    assert_includes html, "flex flex-col min-h-0"
    assert_includes html, "border-l border-[var(--pu-border)]"
  end

  test "slideover does not have centered positioning classes" do
    html = render_html(Plutonium::UI::Modal::Slideover.new)
    refute_includes html, "top-1/2"
    refute_includes html, "-translate-y-1/2"
  end

  test "size defaults to :md" do
    html = render_html(Plutonium::UI::Modal::Slideover.new)
    assert_includes html, Plutonium::UI::Modal::Slideover::SIZE_CLASSES.fetch(:md)
  end

  test "size: dispatches into SIZE_CLASSES" do
    Plutonium::UI::Modal::Slideover::SIZE_CLASSES.each do |size, classes|
      html = render_html(Plutonium::UI::Modal::Slideover.new(size: size))
      assert_includes html, classes, "expected size :#{size} to render #{classes.inspect}"
    end
  end

  test "invalid size: raises ArgumentError" do
    error = assert_raises(ArgumentError) { Plutonium::UI::Modal::Slideover.new(size: :huge) }
    assert_match(/modal size must be one of/, error.message)
  end
end
