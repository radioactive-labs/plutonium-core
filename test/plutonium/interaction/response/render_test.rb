# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Interaction
    module Response
      class RenderTest < ActiveSupport::TestCase
        class MockTurboStream
          attr_reader :replace_calls

          def initialize
            @replace_calls = []
          end

          def replace(target, content)
            @replace_calls << {target: target, content: content}
            "turbo_stream_result"
          end
        end

        class MockViewContext
          def render(*args, **options)
            "rendered_content"
          end
        end

        class MockFormat
          attr_reader :turbo_stream_block, :any_block, :turbo_stream_called, :any_called

          def turbo_stream(&block)
            @turbo_stream_block = block
          end

          def any(&block)
            @any_block = block
          end

          def call_turbo_stream
            @turbo_stream_called = true
            @turbo_stream_block&.call
          end

          def call_any
            @any_called = true
            @any_block&.call
          end
        end

        class MockController
          attr_reader :rendered, :flash
          attr_accessor :turbo_stream, :view_context

          def initialize
            @rendered = nil
            @flash = {}
            @turbo_stream = MockTurboStream.new
            @view_context = MockViewContext.new
          end

          def respond_to
            format = MockFormat.new
            yield format
            @format = format
          end

          # Simulate calling turbo_stream format
          def simulate_turbo_stream_request
            @format.call_turbo_stream
          end

          # Simulate calling any format
          def simulate_any_request
            @format.call_any
          end

          def render(*args, **options)
            @rendered = {args: args, options: options}
          end

          # Make instance_eval pass through
          def instance_eval(&block)
            instance_exec(&block)
          end
        end

        test "initializes with args and options" do
          response = Render.new("component", layout: false)

          # Base class stores args and options
          assert_kind_of Render, response
        end

        test "process sets flash messages before executing" do
          controller = MockController.new
          response = Render.new("component")
          response.with_flash([["Success!", :notice]])

          response.process(controller)

          assert_equal "Success!", controller.flash[:notice]
        end

        test "execute calls respond_to with turbo_stream and any formats" do
          controller = MockController.new
          response = Render.new("component")

          response.process(controller)

          # respond_to was called and registered both formats
          assert_not_nil controller.instance_variable_get(:@format)
        end

        test "turbo_stream format replaces interaction-form with rendered content" do
          controller = MockController.new
          response = Render.new("component", foo: "bar")

          response.process(controller)
          controller.simulate_turbo_stream_request

          # Check that turbo_stream.replace was called with correct target
          assert_equal 1, controller.turbo_stream.replace_calls.size
          call = controller.turbo_stream.replace_calls.first
          assert_equal "interaction-form", call[:target]
          assert_equal "rendered_content", call[:content]
        end

        test "any format renders directly with args and options" do
          controller = MockController.new
          response = Render.new("component", layout: false)

          response.process(controller)
          controller.simulate_any_request

          assert_not_nil controller.rendered
          assert_equal ["component"], controller.rendered[:args]
          assert_equal({layout: false}, controller.rendered[:options])
        end

        test "inherits from Base" do
          response = Render.new("component")

          assert_kind_of Base, response
        end
      end
    end
  end
end
