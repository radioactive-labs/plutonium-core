# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::DynaFrame::ContentTest < ActiveSupport::TestCase
  test "initializes with content proc" do
    content = proc { "test content" }
    component = Plutonium::UI::DynaFrame::Content.new(content)

    assert_equal content, component.instance_variable_get(:@content)
  end

  test "initializes with nil content" do
    component = Plutonium::UI::DynaFrame::Content.new(nil)

    assert_nil component.instance_variable_get(:@content)
  end

  test "initializes with no arguments" do
    component = Plutonium::UI::DynaFrame::Content.new

    assert_nil component.instance_variable_get(:@content)
  end

  test "render_content calls the content proc" do
    called = false
    content = proc {
      called = true
      "result"
    }
    component = Plutonium::UI::DynaFrame::Content.new(content)

    component.render_content

    assert called
  end

  test "render_content handles nil content gracefully" do
    component = Plutonium::UI::DynaFrame::Content.new(nil)

    # Should not raise
    result = component.render_content

    assert_nil result
  end

  test "view_template yields self when no turbo frame" do
    content = proc { "content" }
    component = build_component_without_turbo_frame(content)
    yielded_value = nil

    component.view_template { |frame| yielded_value = frame }

    assert_equal component, yielded_value
  end

  test "view_template wraps content in turbo frame when turbo frame present" do
    content = proc { "content" }
    component = build_component_with_turbo_frame("modal_frame", content)

    # For turbo frame requests, view_template renders the frame directly
    # and does not yield to the caller
    yielded = false
    component.view_template { yielded = true }

    refute yielded, "Should not yield when turbo frame is present"
  end

  test "content is rendered inside turbo frame tag when frame present" do
    content_called = false
    content = proc { content_called = true }
    component = build_component_with_turbo_frame("modal_frame", content)

    component.view_template {}

    assert content_called, "Content should be called inside turbo frame"
  end

  private

  def build_component_without_turbo_frame(content)
    component = Plutonium::UI::DynaFrame::Content.new(content)
    component.define_singleton_method(:current_turbo_frame) { nil }
    component
  end

  def build_component_with_turbo_frame(frame_id, content)
    component = Plutonium::UI::DynaFrame::Content.new(content)
    component.define_singleton_method(:current_turbo_frame) { frame_id }
    # Stub turbo_frame_tag for testing
    component.define_singleton_method(:turbo_frame_tag) { |_id, &inner_block| inner_block&.call }
    component.define_singleton_method(:render) { |*_args| nil }
    component.define_singleton_method(:partial) { |_name| nil }
    component
  end
end
