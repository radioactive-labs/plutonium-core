# frozen_string_literal: true

require "test_helper"

# The bulk-actions toolbar renders the same Action::Base objects as
# ActionButton, so an author's `link:` HTML attribute bag must land on its
# anchors too — the bag deep-merges over the framework's attributes, with
# the author winning on collision.
class Plutonium::UI::BulkActionsToolbarTest < ActiveSupport::TestCase
  Toolbar = Plutonium::UI::Table::Components::BulkActionsToolbar
  Simple = Plutonium::Action::Simple

  test "link: attributes are merged onto the bulk action anchor" do
    action = Simple.new(:export,
      bulk_action: true,
      link: {target: "_blank", data: {analytics: "export"}})
    attrs = capture_action_link(action)

    assert_equal "_blank", attrs[:target]
    assert_equal "export", attrs[:data][:analytics]
    # framework-managed data survives alongside the author keys
    assert_equal "actionButton", attrs[:data][:bulk_actions_target]
  end

  test "author wins when link: collides with a framework-managed key" do
    action = Simple.new(:export,
      bulk_action: true,
      link: {data: {turbo_frame: "custom_frame"}})
    attrs = capture_action_link(action)

    assert_equal "custom_frame", attrs[:data][:turbo_frame]
  end

  test "anchor with no link: bag keeps the framework attributes" do
    action = Simple.new(:export, bulk_action: true)
    attrs = capture_action_link(action)

    assert_includes attrs[:class], "pu-btn"
    assert_equal :export, attrs[:data][:bulk_action_name]
  end

  private

  # Invokes the private per-action render with the terminal link_to helper
  # stubbed to capture the exact attribute hash the render path passed.
  # `attrs` is a required parameter so the test fails loudly if the render
  # path stops passing attributes at all.
  def capture_action_link(action)
    toolbar = Toolbar.new(bulk_actions: [action])
    captured = nil
    toolbar.define_singleton_method(:route_options_to_url) { |*| "/bulk" }
    toolbar.define_singleton_method(:resource_class) { nil }
    toolbar.define_singleton_method(:current_definition) { nil }
    toolbar.define_singleton_method(:link_to) do |_url, attrs, &_blk|
      captured = attrs
      nil
    end
    toolbar.send(:render_action_button, action)
    captured
  end
end
