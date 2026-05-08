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
    assert_includes html, "top-1/2"
    assert_includes html, "-translate-y-1/2"
    assert_includes html, "left-1/2"
    assert_includes html, "-translate-x-1/2"
  end

  test "dialog has max-h-[80vh] class" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    assert_includes html, "max-h-[80vh]"
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

  test "renders inner flex column wrapper" do
    html = render_html(Plutonium::UI::Modal::Centered.new)
    assert_includes html, "flex flex-col h-full max-h-[inherit] min-h-0"
  end
end
