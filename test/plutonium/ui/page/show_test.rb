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

  # Tests for Page::Base hooks inherited by Show

  test "page_type is :show_page" do
    page = build_show_page
    assert_equal :show_page, page.send(:page_type)
  end

  private

  def build_show_page
    page = Plutonium::UI::Page::Show.new

    # Stub out partial rendering to avoid full Rails view context
    page.define_singleton_method(:partial) { |_name| :stubbed_partial }
    page.define_singleton_method(:render) { |_partial| nil }

    page
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
