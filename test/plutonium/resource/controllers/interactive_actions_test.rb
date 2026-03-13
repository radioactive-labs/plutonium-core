# frozen_string_literal: true

require "test_helper"

class Plutonium::Resource::Controllers::InteractiveActionsTest < Minitest::Test
  # Test the modal_layout helper

  def test_modal_layout_returns_false_when_turbo_frame_present
    controller = build_controller_with_turbo_frame("remote_modal")

    result = controller.send(:modal_layout)

    assert_equal false, result
  end

  def test_modal_layout_returns_nil_when_no_turbo_frame
    controller = build_controller_with_turbo_frame(nil)

    result = controller.send(:modal_layout)

    assert_nil result
  end

  def test_modal_layout_returns_nil_for_empty_string_turbo_frame
    controller = build_controller_with_turbo_frame("")

    result = controller.send(:modal_layout)

    assert_nil result
  end

  def test_modal_layout_returns_false_for_any_turbo_frame_id
    controller = build_controller_with_turbo_frame("custom_frame")

    result = controller.send(:modal_layout)

    assert_equal false, result
  end

  private

  def build_controller_with_turbo_frame(frame_id)
    controller = TestableInteractiveController.new
    controller.test_turbo_frame = frame_id
    controller
  end

  class TestableInteractiveController < ActionController::Base
    include Plutonium::Resource::Controllers::InteractiveActions

    attr_accessor :test_turbo_frame

    def helpers
      @helpers ||= Struct.new(:current_turbo_frame).new(test_turbo_frame)
    end

    # Stub required methods
    def current_definition
      nil
    end
  end
end
