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

  # The form modal offers the same "open full page" affordance the show modal
  # has. It targets a new tab, so the modal — and anything already typed into
  # it — is left untouched.
  test "modal form carries an open-full-page URL" do
    page = build_new_page(turbo_frame: "remote_modal")
    assert_equal "/admin/things/new", captured_modal(page).instance_variable_get(:@open_full_url)
  end

  # `return_to` decides where the form lands after submitting, and
  # `kanban_column` decides which column a quick-add's record joins. Dropping
  # the query string (as a bare request.path would) silently loses both.
  test "open-full-page URL keeps params the standalone form still needs" do
    page = build_new_page(
      turbo_frame: "remote_modal",
      query_params: {"return_to" => "/admin/things", "kanban_column" => "active"}
    )
    url = captured_modal(page).instance_variable_get(:@open_full_url)

    assert_includes url, "return_to=%2Fadmin%2Fthings"
    assert_includes url, "kanban_column=active"
  end

  # `kanban_modal` is the one param that must not survive: it marks a kanban
  # card's modal, where the show page hides its metadata rail.
  test "open-full-page URL drops the modal-only kanban_modal flag" do
    page = build_new_page(
      turbo_frame: "remote_modal",
      query_params: {"kanban_modal" => "1", "return_to" => "/admin/things"}
    )
    url = captured_modal(page).instance_variable_get(:@open_full_url)

    refute_includes url, "kanban_modal"
    assert_includes url, "return_to=%2Fadmin%2Fthings"
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

  # Renders the modal path and returns the modal component that was built.
  def captured_modal(page)
    captured = nil
    page.define_singleton_method(:render) { |component, &block| captured ||= component }
    page.send(:render_default_content)
    captured
  end

  def build_new_page(turbo_frame: nil, modal_mode: :slideover, query_params: {})
    page = Plutonium::UI::Page::New.new

    page.define_singleton_method(:current_turbo_frame) { turbo_frame }
    page.define_singleton_method(:in_frame?) { !turbo_frame.nil? }
    page.define_singleton_method(:in_modal?) { turbo_frame == Plutonium::REMOTE_MODAL_FRAME }
    page.define_singleton_method(:partial) { |_name| :resource_form_partial }
    page.define_singleton_method(:render) { |_partial| nil }
    # The modal's "open full page" link reads request.path.
    page.define_singleton_method(:request) {
      Struct.new(:path, :query_parameters).new("/admin/things/new", query_params)
    }

    definition = build_definition(modal_mode)
    page.define_singleton_method(:current_definition) { definition }
    page.define_singleton_method(:page_title) { "New Resource" }
    page.define_singleton_method(:page_description) { nil }

    page
  end

  def build_definition(modal_mode)
    definition = Object.new
    definition.define_singleton_method(:modal_mode) { modal_mode }
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
