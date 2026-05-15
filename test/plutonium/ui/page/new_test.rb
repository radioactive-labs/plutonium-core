# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Page::NewTest < ActiveSupport::TestCase
  test "page_type is :new_page" do
    page = build_new_page
    assert_equal :new_page, page.send(:page_type)
  end

  test "render_default_content wraps form in pb-20 div when not in modal" do
    page = build_new_page(turbo_frame: nil)
    output = render_default_content(page)

    assert_includes output, "pb-20"
  end

  test "render_default_content renders resource_form partial when not in modal" do
    page = build_new_page(turbo_frame: nil)
    partial_rendered = false
    page.define_singleton_method(:partial) { |_name| :resource_form_partial }
    page.define_singleton_method(:render) { |_partial| partial_rendered = true }

    render_default_content(page)

    assert partial_rendered, "resource_form partial should be rendered"
  end

  test "render_default_content renders Modal::Slideover by default when in modal" do
    page = build_new_page(turbo_frame: "remote_modal", modal_mode: :slideover)
    first_render = nil

    page.define_singleton_method(:render) do |component, &block|
      first_render ||= component.class
      block&.call
    end

    page.send(:render_default_content)

    assert_equal Plutonium::UI::Modal::Slideover, first_render
  end

  test "render_default_content renders Modal::Centered when definition declares modal :centered" do
    page = build_new_page(turbo_frame: "remote_modal", modal_mode: :centered)
    first_render = nil

    page.define_singleton_method(:render) do |component, &block|
      first_render ||= component.class
      block&.call
    end

    page.send(:render_default_content)

    assert_equal Plutonium::UI::Modal::Centered, first_render
  end

  test "render_default_content does not render modal when in different frame" do
    page = build_new_page(turbo_frame: "some_other_frame")
    output = render_default_content(page)

    assert_includes output, "pb-20"
  end

  test "in_frame? returns true when current_turbo_frame is present" do
    page = build_new_page(turbo_frame: "some_frame")
    assert page.send(:in_frame?)
  end

  test "in_frame? returns false when current_turbo_frame is nil" do
    page = build_new_page(turbo_frame: nil)
    refute page.send(:in_frame?)
  end

  test "in_modal? returns true when current_turbo_frame is remote_modal" do
    page = build_new_page(turbo_frame: "remote_modal")
    assert page.send(:in_modal?)
  end

  test "in_modal? returns false when current_turbo_frame is nil" do
    page = build_new_page(turbo_frame: nil)
    refute page.send(:in_modal?)
  end

  test "in_modal? returns false when current_turbo_frame is a different frame" do
    page = build_new_page(turbo_frame: "other_frame")
    refute page.send(:in_modal?)
  end

  private

  def build_new_page(turbo_frame: nil, modal_mode: :slideover)
    page = Plutonium::UI::Page::New.new

    page.define_singleton_method(:current_turbo_frame) { turbo_frame }
    page.define_singleton_method(:in_frame?) { !turbo_frame.nil? }
    page.define_singleton_method(:in_modal?) { turbo_frame == Plutonium::REMOTE_MODAL_FRAME }
    page.define_singleton_method(:partial) { |_name| :resource_form_partial }
    page.define_singleton_method(:render) { |_partial| nil }

    definition = build_definition(modal_mode)
    page.define_singleton_method(:current_definition) { definition }
    page.define_singleton_method(:page_title) { "New Resource" }
    page.define_singleton_method(:page_description) { nil }

    page
  end

  def build_definition(modal_mode)
    definition = Object.new
    definition.define_singleton_method(:modal) { modal_mode }
    definition.define_singleton_method(:modal_size) { :md }
    definition.define_singleton_method(:new_page_title) { nil }
    definition.define_singleton_method(:new_page_description) { nil }
    definition
  end

  # Renders render_default_content in a stubbed HTML context and returns the output string.
  def render_default_content(page)
    output_parts = []

    page.define_singleton_method(:div) do |**attrs, &inner|
      output_parts << "<div class=\"#{attrs[:class]}\">"
      inner&.call
      output_parts << "</div>"
    end

    page.send(:render_default_content)

    output_parts.join
  end
end
