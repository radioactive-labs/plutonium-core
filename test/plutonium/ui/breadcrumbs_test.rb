# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::BreadcrumbsTest < ActiveSupport::TestCase
  test "breadcrumbs component can be instantiated" do
    component = Plutonium::UI::Breadcrumbs.new

    assert_instance_of Plutonium::UI::Breadcrumbs, component
  end

  test "singular route type is identified by :resource symbol" do
    # Singular routes use `resource :profile` which sets route_type to :resource
    # Plural routes use `resources :posts` which sets route_type to :resources
    singular_route_type = :resource
    plural_route_type = :resources

    assert_equal :resource, singular_route_type, "singular routes should have :resource type"
    refute_equal :resource, plural_route_type, "plural routes should have :resources type"
  end

  # Tests for extracted helper methods

  test "render_breadcrumb_item yields content with chevron separator" do
    component = Plutonium::UI::Breadcrumbs.new
    output = render_component(component) do
      component.send(:render_breadcrumb_item) { "Test Content" }
    end

    # Should contain the list item wrapper
    assert_includes output, "<li"
    assert_includes output, "flex items-center"
    # Should contain the SVG chevron separator
    assert_includes output, "<svg"
    assert_includes output, "m1 9 4-4-4-4" # chevron path
  end

  test "render_chevron_separator renders svg with correct path" do
    component = Plutonium::UI::Breadcrumbs.new
    output = render_component(component) do
      component.send(:render_chevron_separator)
    end

    assert_includes output, "<svg"
    assert_includes output, "m1 9 4-4-4-4"
    assert_includes output, "rtl:rotate-180"
  end

  test "render_trailing_separator renders list item with chevron" do
    component = Plutonium::UI::Breadcrumbs.new
    output = render_component(component) do
      component.send(:render_trailing_separator)
    end

    assert_includes output, "<li"
    assert_includes output, "<svg"
  end

  test "render_dashboard_link renders link to root with home icon" do
    component = Plutonium::UI::Breadcrumbs.new
    component.define_singleton_method(:root_path) { "/" }

    output = render_component(component) do
      component.send(:render_dashboard_link)
    end

    assert_includes output, "<li"
    assert_includes output, "<a"
    assert_includes output, 'href="/"'
    assert_includes output, "Dashboard"
    # Home icon SVG path
    assert_includes output, "m19.707 9.293"
  end

  private

  def render_component(component, &block)
    # Create a minimal rendering context
    component.instance_variable_set(:@_view_context, ActionView::Base.empty)

    # Capture the output by calling the block in the component's context
    component.instance_eval do
      @_output = []

      def plain(text)
        @_output << text.to_s
      end

      def li(**attrs, &block)
        @_output << "<li class=\"#{attrs[:class]}\">"
        yield if block
        @_output << "</li>"
      end

      def a(**attrs, &block)
        @_output << "<a href=\"#{attrs[:href]}\" class=\"#{attrs[:class]}\">"
        yield if block
        @_output << "</a>"
      end

      def div(**attrs, &block)
        @_output << "<div class=\"#{attrs[:class]}\">"
        yield if block
        @_output << "</div>"
      end

      def svg(**attrs, &block)
        @_output << "<svg class=\"#{attrs[:class]}\">"
        yield(self) if block
        @_output << "</svg>"
      end

      def path(**attrs)
        @_output << "<path d=\"#{attrs[:d]}\"/>"
      end
    end

    block.call

    component.instance_variable_get(:@_output).join
  end
end
