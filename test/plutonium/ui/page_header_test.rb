# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::PageHeaderTest < ActiveSupport::TestCase
  # Tests for view_template structure

  test "outer div uses flex items-start justify-between gap-4 mb-4" do
    component = build_component(title: "Title", description: nil, actions: [])
    output = render_view_template(component)

    assert_includes output, "flex items-start justify-between gap-4 mb-4"
  end

  test "inner wrapper uses min-w-0 flex-1" do
    component = build_component(title: "Title", description: nil, actions: [])
    output = render_view_template(component)

    assert_includes output, "min-w-0 flex-1"
  end

  # Tests for render_title

  test "render_title renders h1 with correct classes" do
    component = build_component(title: "My Page", description: nil, actions: [])
    output = render_component(component) { component.send(:render_title, "My Page") }

    assert_includes output, "<h1"
    assert_includes output, "text-xl font-semibold leading-tight"
    assert_includes output, "text-[var(--pu-text)]"
    assert_includes output, "truncate"
    assert_includes output, "My Page"
  end

  # Tests for render_description

  test "render_description renders p with correct classes" do
    component = build_component(title: "Title", description: "A description", actions: [])
    output = render_component(component) { component.send(:render_description, "A description") }

    assert_includes output, "<p"
    assert_includes output, "mt-1 text-sm text-[var(--pu-text-muted)]"
    assert_includes output, "A description"
  end

  # Tests for description presence logic

  test "description is omitted when nil" do
    component = build_component(title: "Title", description: nil, actions: [])
    output = render_view_template(component)

    refute_includes output, "<p"
  end

  test "description is omitted when blank" do
    component = build_component(title: "Title", description: "", actions: [])
    output = render_view_template(component)

    refute_includes output, "<p"
  end

  test "description is rendered when present" do
    component = build_component(title: "Title", description: "Some text", actions: [])
    output = render_view_template(component)

    assert_includes output, "<p"
    assert_includes output, "Some text"
  end

  # Tests for actions presence logic

  test "actions section is omitted when actions is empty" do
    actions_rendered = false
    component = build_component(title: "Title", description: nil, actions: [])
    component.define_singleton_method(:render_actions) { actions_rendered = true }

    render_view_template(component)

    refute actions_rendered, "render_actions should not be called when actions is empty"
  end

  test "actions section is rendered when actions are present" do
    actions_rendered = false
    mock_action = build_mock_action
    component = build_component(title: "Title", description: nil, actions: [mock_action])
    component.define_singleton_method(:render_actions) { actions_rendered = true }

    render_view_template(component)

    assert actions_rendered, "render_actions should be called when actions are present"
  end

  private

  def build_component(title:, description:, actions:)
    Plutonium::UI::PageHeader.new(title: title, description: description, actions: actions)
  end

  def build_mock_action
    action = Object.new
    action.define_singleton_method(:category) do
      cat = Object.new
      cat.define_singleton_method(:primary?) { true }
      cat
    end
    action.define_singleton_method(:position) { 0 }
    action
  end

  # Renders the full view_template of the component with stubbed HTML helpers.
  def render_view_template(component)
    component.define_singleton_method(:phlexi_render) do |value, &block|
      block.call if block && value
    end

    render_component(component) { component.view_template }
  end

  # Renders arbitrary block in the context of the component with HTML stubs.
  def render_component(component, &block)
    output_parts = []

    component.define_singleton_method(:div) do |**attrs, &inner|
      output_parts << "<div class=\"#{attrs[:class]}\">"
      inner&.call
      output_parts << "</div>"
    end

    component.define_singleton_method(:h1) do |**attrs, &inner|
      output_parts << "<h1 class=\"#{attrs[:class]}\">"
      output_parts << inner.call.to_s if inner
      output_parts << "</h1>"
    end

    component.define_singleton_method(:p) do |**attrs, &inner|
      output_parts << "<p class=\"#{attrs[:class]}\">"
      output_parts << inner.call.to_s if inner
      output_parts << "</p>"
    end

    block.call

    output_parts.join
  end
end
