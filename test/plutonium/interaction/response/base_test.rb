# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Interaction
    module Response
      class BaseTest < ActiveSupport::TestCase
        class MockController
          attr_reader :flash

          def initialize
            @flash = {}
          end
        end

        class ConcreteResponse < Base
          attr_reader :execute_called, :block_result

          def execute(controller, &block)
            @execute_called = true
            @block_result = block&.call
          end
        end

        test "initializes with empty flash array" do
          response = ConcreteResponse.new

          assert_equal [], response.flash
        end

        test "initializes with args and options" do
          response = ConcreteResponse.new("arg1", "arg2", key: "value")

          assert_equal ["arg1", "arg2"], response.instance_variable_get(:@args)
          assert_equal({key: "value"}, response.instance_variable_get(:@options))
        end

        test "with_flash adds messages to flash array" do
          response = ConcreteResponse.new
          response.with_flash([["Message 1", :notice], ["Message 2", :alert]])

          assert_equal 2, response.flash.size
          assert_equal ["Message 1", :notice], response.flash[0]
          assert_equal ["Message 2", :alert], response.flash[1]
        end

        test "with_flash returns self for chaining" do
          response = ConcreteResponse.new

          result = response.with_flash([["Message", :notice]])

          assert_same response, result
        end

        test "with_flash ignores blank messages" do
          response = ConcreteResponse.new
          response.with_flash(nil)
          response.with_flash([])

          assert_equal [], response.flash
        end

        test "process sets flash on controller" do
          controller = MockController.new
          response = ConcreteResponse.new
          response.with_flash([["Success!", :notice], ["Warning!", :alert]])

          response.process(controller)

          assert_equal "Success!", controller.flash[:notice]
          assert_equal "Warning!", controller.flash[:alert]
        end

        test "process calls execute" do
          controller = MockController.new
          response = ConcreteResponse.new

          response.process(controller)

          assert response.execute_called
        end

        test "process passes block to execute" do
          controller = MockController.new
          response = ConcreteResponse.new

          response.process(controller) { "block result" }

          assert_equal "block result", response.block_result
        end

        test "base execute raises NotImplementedError" do
          controller = MockController.new
          response = Base.new

          error = assert_raises(NotImplementedError) do
            response.process(controller)
          end

          assert_match(/must implement #execute/, error.message)
        end
      end
    end
  end
end
