# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::SectionTest < Minitest::Test
  Section = Plutonium::Definition::FormLayout::Section
  ResolvedSection = Plutonium::Definition::FormLayout::ResolvedSection
  Component = Plutonium::UI::Form::Components::Section

  def render_section(section, fields: %i[a])
    resolved = ResolvedSection.new(section:, fields:)
    component = Component.new(resolved, grid_class: "grid grid-cols-2")

    # Stub Phlex DSL methods directly on the component instance, matching the
    # pattern used throughout test/plutonium/ui/ (e.g. page_header_test.rb,
    # breadcrumbs_test.rb). No view context is needed because the component
    # itself is not fully called through Phlex's rendering pipeline.
    output = []

    component.define_singleton_method(:div) do |**attrs, &block|
      output << %(<div class="#{attrs[:class]}">)
      block&.call
      output << "</div>"
    end

    component.define_singleton_method(:details) do |**attrs, &block|
      open_attr = (attrs.key?(:open) && attrs[:open]) ? " open" : ""
      output << %(<details class="#{attrs[:class]}"#{open_attr}>)
      block&.call
      output << "</details>"
    end

    component.define_singleton_method(:summary) do |**attrs, &block|
      output << %(<summary class="#{attrs[:class]}">)
      block&.call
      output << "</summary>"
    end

    component.define_singleton_method(:h3) do |**attrs, &block|
      output << %(<h3 class="#{attrs[:class]}">)
      output << block.call.to_s if block
      output << "</h3>"
    end

    component.define_singleton_method(:p) do |**attrs, &block|
      output << %(<p class="#{attrs[:class]}">)
      output << block.call.to_s if block
      output << "</p>"
    end

    component.define_singleton_method(:plain) do |text|
      output << text.to_s
    end

    component.view_template { component.plain("FIELD") }

    output.join
  end

  def test_renders_heading_and_description
    html = render_section(Section.new(key: :identity, fields: %i[a],
      options: {label: "Your identification", description: "Basic"}))
    assert_includes html, "Your identification"
    assert_includes html, "Basic"
    assert_includes html, %(class="grid grid-cols-2")
    assert_includes html, "FIELD"
  end

  def test_collapsible_open_by_default
    html = render_section(Section.new(key: :address, fields: %i[a],
      options: {collapsible: true}))
    assert_match(/<details[^>]*\bopen\b/, html)
    assert_includes html, "<summary"
  end

  def test_collapsed_omits_open
    html = render_section(Section.new(key: :address, fields: %i[a],
      options: {collapsible: true, collapsed: true}))
    assert_match(/<details(?![^>]*\bopen\b)/, html)
  end

  def test_non_collapsible_has_no_details
    html = render_section(Section.new(key: :identity, fields: %i[a], options: {}))
    refute_includes html, "<details"
    assert_includes html, "Identity"
  end
end
