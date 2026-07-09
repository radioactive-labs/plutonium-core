# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Page::ShowTest < ActiveSupport::TestCase
  # Tests for aside_present? default

  test "aside_present? returns false by default" do
    page = build_show_page
    refute page.send(:aside_present?), "aside_present? should return false by default"
  end

  test "render_aside is a no-op by default" do
    page = build_show_page
    result = page.send(:render_aside)
    assert_nil result
  end

  # Tests for render_default_content — single-column path

  test "render_default_content single-column path does not use grid layout" do
    page = build_show_page
    output = render_default_content(page)

    refute_includes output, "grid-cols-[minmax(0,1fr)_240px]"
  end

  test "render_default_content renders resource_details partial in single-column path" do
    page = build_show_page
    partial_rendered = false
    page.define_singleton_method(:partial) { |_name| :resource_details_partial }
    page.define_singleton_method(:render) { |_partial| partial_rendered = true }

    render_default_content(page)

    assert partial_rendered, "resource_details partial should be rendered"
  end

  # Tests for render_default_content — aside (grid) path

  test "render_default_content uses grid layout when aside_present? is true" do
    page = build_show_page_with_aside
    output = render_default_content(page)

    assert_includes output, "grid"
    assert_includes output, "lg:grid-cols-[minmax(0,1fr)_240px]"
    assert_includes output, "gap-6"
  end

  test "render_default_content renders aside element when aside_present? is true" do
    page = build_show_page_with_aside
    output = render_default_content(page)

    assert_includes output, "<aside"
    assert_includes output, "hidden lg:block"
  end

  test "render_default_content single-column path does not produce aside element" do
    page = build_show_page
    output = render_default_content(page)

    refute_includes output, "<aside"
  end

  # Tests for render_default_content — modal path (show_in :modal)
  #
  # The show page is ALWAYS centered when in a modal, regardless of the
  # definition's modal_mode (which styles :new/:edit). These two cases assert
  # that decoupling: slideover and centered modal_mode both yield Centered.

  test "render_default_content renders Modal::Centered when in modal (modal_mode :slideover)" do
    page = build_show_page(turbo_frame: "remote_modal", modal_mode: :slideover)
    first_render = nil
    # Capture only which modal is chosen — the body block calls `div`, which
    # needs a live Phlex buffer this isolated unit test doesn't provide (the
    # rendered body is covered by the modal integration tests).
    page.define_singleton_method(:render) do |component|
      first_render ||= component.class
    end

    page.send(:render_default_content)

    assert_equal Plutonium::UI::Modal::Centered, first_render,
      "show must always be centered, even when modal_mode is :slideover"
  end

  test "render_default_content renders Modal::Centered when modal_mode :centered too" do
    page = build_show_page(turbo_frame: "remote_modal", modal_mode: :centered)
    first_render = nil
    # Capture only which modal is chosen — the body block calls `div`, which
    # needs a live Phlex buffer this isolated unit test doesn't provide (the
    # rendered body is covered by the modal integration tests).
    page.define_singleton_method(:render) do |component|
      first_render ||= component.class
    end

    page.send(:render_default_content)

    assert_equal Plutonium::UI::Modal::Centered, first_render
  end

  test "modal details carry an open-full-page URL (request.path)" do
    page = build_show_page(turbo_frame: "remote_modal", modal_mode: :slideover)
    captured = nil
    page.define_singleton_method(:render) do |component|
      captured ||= component
    end

    page.send(:render_default_content)

    assert_equal "/admin/things/7", captured.instance_variable_get(:@open_full_url)
  end

  test "render_default_content does not render a modal when in a different frame" do
    page = build_show_page(turbo_frame: "some_other_frame")
    rendered = nil
    page.define_singleton_method(:render) { |arg| rendered = arg }

    page.send(:render_default_content)

    assert_equal :stubbed_partial, rendered, "non-modal frame should render the details partial, not a modal"
  end

  # Tests for Page::Base hooks inherited by Show

  test "page_type is :show_page" do
    page = build_show_page
    assert_equal :show_page, page.send(:page_type)
  end

  private

  def build_show_page(turbo_frame: nil, modal_mode: :slideover)
    page = Plutonium::UI::Page::Show.new

    # Stub frame/modal detection so unit tests can drive render_default_content
    # without a live request (in_modal? reads request.headers otherwise).
    page.define_singleton_method(:current_turbo_frame) { turbo_frame }
    page.define_singleton_method(:in_frame?) { !turbo_frame.nil? }
    page.define_singleton_method(:in_modal?) { turbo_frame == Plutonium::REMOTE_MODAL_FRAME }

    definition = build_definition(modal_mode)
    page.define_singleton_method(:current_definition) { definition }
    page.define_singleton_method(:page_title) { "Show Resource" }
    page.define_singleton_method(:page_description) { nil }
    # render_modal_details reads request.path for the open-full link.
    page.define_singleton_method(:request) { Struct.new(:path).new("/admin/things/7") }

    # Stub out partial rendering to avoid full Rails view context
    page.define_singleton_method(:partial) { |_name| :stubbed_partial }
    page.define_singleton_method(:render) { |_partial| nil }

    page
  end

  def build_definition(modal_mode)
    definition = Object.new
    definition.define_singleton_method(:modal_mode) { modal_mode }
    definition.define_singleton_method(:modal_size) { :md }
    definition.define_singleton_method(:show_page_title) { nil }
    definition.define_singleton_method(:show_page_description) { nil }
    definition
  end

  def build_show_page_with_aside
    page = build_show_page

    page.define_singleton_method(:aside_present?) { true }
    page.define_singleton_method(:render_aside) { nil }

    page
  end

  # Renders render_default_content in a stubbed HTML context and returns the output string.
  def render_default_content(page)
    output_parts = []

    page.define_singleton_method(:div) do |**attrs, &inner|
      output_parts << "<div class=\"#{attrs[:class]}\">"
      inner&.call
      output_parts << "</div>"
    end

    page.define_singleton_method(:aside) do |**attrs, &inner|
      output_parts << "<aside class=\"#{attrs[:class]}\">"
      inner&.call
      output_parts << "</aside>"
    end

    page.send(:render_default_content)

    output_parts.join
  end
end
