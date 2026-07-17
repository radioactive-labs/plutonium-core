# frozen_string_literal: true

require "test_helper"

# ActionButton splats an action's author-supplied HTML attribute bags onto the
# rendered element: `link:` onto the <a> (GET link + dropdown item), `button:`
# onto the button_to <form> (non-GET). The bag deep-merges over the framework's
# own attributes, with the author winning on collision.
#
# These tests stub the Phlex link/button helpers to capture the exact attribute
# hash emitted, rather than asserting on stringified HTML.
class Plutonium::UI::ActionButtonTest < ActiveSupport::TestCase
  ActionButton = Plutonium::UI::ActionButton
  Simple = Plutonium::Action::Simple
  RouteOptions = Plutonium::Action::RouteOptions

  # --- render_link (GET) -----------------------------------------------------

  test "link: attributes are splatted onto the anchor in the GET link" do
    action = Simple.new(:docs, link: {target: "_blank", rel: "noopener noreferrer"})
    attrs = capture_link(action)

    assert_equal "_blank", attrs[:target]
    assert_equal "noopener noreferrer", attrs[:rel]
  end

  test "link: data deep-merges with the framework's managed data" do
    action = Simple.new(:docs, link: {data: {analytics: "docs-click"}})
    attrs = capture_link(action)

    # framework key preserved, author key added
    assert attrs[:data].key?(:turbo_frame)
    assert_equal "docs-click", attrs[:data][:analytics]
  end

  test "author wins when link: collides with a framework-managed key" do
    action = Simple.new(:docs, link: {data: {turbo_frame: "custom_frame"}})
    attrs = capture_link(action)

    assert_equal "custom_frame", attrs[:data][:turbo_frame]
  end

  test "GET link with no link: bag is unchanged" do
    action = Simple.new(:docs)
    attrs = capture_link(action)

    # the framework attributes must actually be there — an empty capture
    # would mean the render path stopped passing attributes, not "unchanged"
    assert_equal "pu-btn", attrs[:class]
    assert attrs[:data].key?(:turbo_frame)
    refute attrs.key?(:target)
  end

  # --- render_dropdown_item --------------------------------------------------

  test "link: attributes are splatted onto the dropdown anchor" do
    action = Simple.new(:docs, link: {target: "_blank", rel: "noopener"})
    attrs = capture_dropdown(action)

    assert_equal "_blank", attrs[:target]
    assert_equal "noopener", attrs[:rel]
  end

  # --- render_button (non-GET) -----------------------------------------------

  test "button: attributes are merged into the button_to form options" do
    action = Simple.new(:archive,
      route_options: RouteOptions.new(method: :delete),
      button: {target: "_top", data: {custom: "x"}})
    opts = capture_button(action)

    assert_equal "_top", opts[:form][:target]
    assert_equal "x", opts[:form][:data][:custom]
  end

  test "button: data deep-merges with the framework's managed form data" do
    action = Simple.new(:archive,
      route_options: RouteOptions.new(method: :delete),
      button: {data: {custom: "x"}})
    opts = capture_button(action)

    # framework keys survive alongside the author key
    assert opts[:form][:data].key?(:turbo_frame)
    assert_equal "x", opts[:form][:data][:custom]
  end

  private

  def capture_link(action) = capture_attributes(action, :link_to)

  def capture_dropdown(action) = capture_attributes(action, :a, variant: :dropdown)

  def capture_button(action) = capture_attributes(action, :button_to)

  # Renders the component with the terminal render helper stubbed out and
  # returns the attribute hash the render path passed to it. Each stub
  # enforces the one calling convention its render path actually uses
  # (positional hash for link_to, kwargs splat for a/button_to), so a render
  # path that stops passing attributes fails loudly instead of capturing {}.
  def capture_attributes(action, helper, variant: :default)
    button = ActionButton.new(action, url: "/things", variant: variant)
    captured = nil
    {
      current_definition: nil,
      url_with_return_to: "/things",
      return_to_url: "/back",
      button_classes: "pu-btn",
      dropdown_item_classes: "item"
    }.each do |name, value|
      button.define_singleton_method(name) { value }
    end
    case helper
    when :link_to
      button.define_singleton_method(:link_to) do |_url, attrs, &_blk|
        captured = attrs
        nil
      end
    when :a
      button.define_singleton_method(:a) do |**attrs, &_blk|
        captured = attrs
        nil
      end
    when :button_to
      button.define_singleton_method(:button_to) do |_url, **opts, &_blk|
        captured = opts
        nil
      end
    end
    button.view_template
    captured
  end
end
