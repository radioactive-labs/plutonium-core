# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Interaction
    module Response
      class FailureTest < ActiveSupport::TestCase
        class MockController
          attr_reader :flash

          def initialize
            @flash = {}
          end
        end

        test "inherits from Base" do
          response = Failure.new

          assert_kind_of Base, response
        end

        test "execute yields to block" do
          controller = MockController.new
          response = Failure.new
          block_called = false

          response.process(controller) { block_called = true }

          assert block_called
        end

        test "execute returns block result" do
          controller = MockController.new
          response = Failure.new
          result = nil

          response.process(controller) { result = "failure handled" }

          assert_equal "failure handled", result
        end

        test "process sets flash before yielding" do
          controller = MockController.new
          response = Failure.new
          response.with_flash([["Error occurred", :alert]])
          flash_value_during_block = nil

          response.process(controller) do
            flash_value_during_block = controller.flash[:alert]
          end

          assert_equal "Error occurred", flash_value_during_block
        end
      end
    end
  end
end
