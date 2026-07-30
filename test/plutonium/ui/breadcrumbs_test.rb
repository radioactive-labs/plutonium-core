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

  test "foldable breadcrumb items are measurable and tagged for the controller" do
    component = Plutonium::UI::Breadcrumbs.new
    output = render_component(component) do
      component.send(:render_breadcrumb_item, foldable: true) { "Middle" }
    end

    # `shrink-0` so the controller measures natural widths — proportional CSS
    # shrinking would truncate every label into a stub instead of folding.
    li_classes = output[/<li class="([^"]*)"/, 1]
    assert_includes li_classes, "shrink-0"
    assert_includes output, 'data-breadcrumbs-target="item"'
  end

  test "the last breadcrumb item is never foldable but can ellipsize" do
    component = Plutonium::UI::Breadcrumbs.new
    output = render_component(component) do
      component.send(:render_breadcrumb_item, foldable: false) { "Current" }
    end

    li_classes = output[/<li class="([^"]*)"/, 1]
    refute_includes li_classes, "hidden"
    # min-w-0 lets the controller drop shrink-0 as a last resort.
    assert_includes li_classes, "min-w-0"
    assert_includes output, 'data-breadcrumbs-target="last"'
  end

  test "the overflow menu starts hidden and lists every foldable segment" do
    component = Plutonium::UI::Breadcrumbs.new
    component.define_singleton_method(:middle_items) do
      [component.send(:segment, "Posts", "/posts")]
    end
    # `segment` builds a link via Rails' link_to; stub it to the harness's <a>.
    component.define_singleton_method(:link_to) do |url, **attrs, &blk|
      a(href: url, class: attrs[:class], &blk)
    end

    output = render_component(component) do
      component.send(:render_overflow_menu)
    end

    # Hidden until the controller actually folds something away.
    assert_includes output[/<li class="([^"]*)"/, 1], "hidden"
    assert_includes output, 'data-breadcrumbs-target="overflow"'
    assert_includes output, 'data-breadcrumbs-target="menuItem"'
    # Reuses the shared dropdown controller rather than a bespoke one.
    assert_includes output, 'data-controller="resource-drop-down"'
    assert_includes output, 'data-resource-drop-down-target="trigger"'
    assert_includes output, 'data-resource-drop-down-target="menu"'
    assert_includes output, "TablerIcons::Dots"
    # The foldable segments are listed inside the popup as real links.
    assert_includes output, 'href="/posts"'
    assert_includes output, "Posts"
  end

  test "middle_items excludes the last segment, which is never folded" do
    component = Plutonium::UI::Breadcrumbs.new
    component.instance_variable_set(:@breadcrumb_items, [:a, :b, :c])

    assert_equal [:a, :b], component.send(:middle_items)
  end

  test "middle_items is empty when there is only one segment" do
    component = Plutonium::UI::Breadcrumbs.new
    component.instance_variable_set(:@breadcrumb_items, [:only])

    assert_empty component.send(:middle_items)
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

      # Renders `data: {foo_bar: "x"}` as ` data-foo-bar="x"` so tests can
      # assert on the Stimulus wiring the component emits.
      def data_attrs(attrs)
        (attrs[:data] || {}).map { |k, v| " data-#{k.to_s.tr("_", "-")}=\"#{v}\"" }.join
      end

      def element(tag, attrs, &block)
        @_output << "<#{tag} class=\"#{attrs[:class]}\"#{data_attrs(attrs)}>"
        yield if block
        @_output << "</#{tag}>"
      end

      def li(**attrs, &block) = element("li", attrs, &block)

      def span(**attrs, &block) = element("span", attrs, &block)

      def button(**attrs, &block) = element("button", attrs, &block)

      def div(**attrs, &block) = element("div", attrs, &block)

      def ul(**attrs, &block) = element("ul", attrs, &block)

      def a(**attrs, &block)
        @_output << "<a href=\"#{attrs[:href]}\" class=\"#{attrs[:class]}\">"
        yield if block
        @_output << "</a>"
      end

      # Nested Phlex components (e.g. Tabler icons) render as a marker so tests
      # can assert which component was used without a real render context.
      def render(component)
        @_output << "<#{component.class.name}/>"
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
