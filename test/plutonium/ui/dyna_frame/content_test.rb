# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::DynaFrame::ContentTest < ActiveSupport::TestCase
  test "view_template yields the block when no turbo frame" do
    component = build_component(turbo_frame: nil)
    yielded = false

    component.view_template { yielded = true }

    assert yielded
  end

  test "view_template does not yield when no block and no turbo frame" do
    component = build_component(turbo_frame: nil)
    # Should simply do nothing, not raise
    assert_nil component.view_template
  end

  test "view_template wraps block in turbo_frame_tag when turbo frame present" do
    component = build_component(turbo_frame: "modal_frame")
    captured_frame_id = nil
    component.define_singleton_method(:turbo_frame_tag) do |id, &inner|
      captured_frame_id = id
      inner&.call
    end
    component.define_singleton_method(:partial) { |_name| nil }
    component.define_singleton_method(:render) { |_partial| nil }

    component.view_template { "content" }

    assert_equal "modal_frame", captured_frame_id
  end

  test "view_template renders flash partial inside turbo frame" do
    component = build_component(turbo_frame: "modal_frame")
    rendered_partials = []
    component.define_singleton_method(:partial) { |name| name }
    component.define_singleton_method(:render) { |partial| rendered_partials << partial }
    component.define_singleton_method(:turbo_frame_tag) { |_id, &inner| inner&.call }

    component.view_template { "content" }

    assert_includes rendered_partials, "flash"
  end

  test "view_template yields the block inside the turbo frame" do
    component = build_component(turbo_frame: "modal_frame")
    component.define_singleton_method(:partial) { |_name| nil }
    component.define_singleton_method(:render) { |_partial| nil }
    component.define_singleton_method(:turbo_frame_tag) { |_id, &inner| inner&.call }
    yielded = false

    component.view_template { yielded = true }

    assert yielded
  end

  private

  def build_component(turbo_frame:)
    component = Plutonium::UI::DynaFrame::Content.new
    component.define_singleton_method(:current_turbo_frame) { turbo_frame }
    component
  end
end
