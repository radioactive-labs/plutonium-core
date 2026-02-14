# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Interaction
    module Response
      class NullTest < ActiveSupport::TestCase
        class MockController
          attr_reader :flash

          def initialize
            @flash = {}
          end
        end

        test "inherits from Base" do
          response = Null.new("result")

          assert_kind_of Base, response
        end

        test "initializes with result value" do
          response = Null.new("my result")

          assert_equal "my result", response.result
        end

        test "initializes with complex result" do
          record = {id: 1, name: "Test"}
          response = Null.new(record)

          assert_equal record, response.result
        end

        test "execute yields result to block" do
          controller = MockController.new
          response = Null.new("yielded value")
          yielded = nil

          response.process(controller) { |result| yielded = result }

          assert_equal "yielded value", yielded
        end

        test "execute yields nil result" do
          controller = MockController.new
          response = Null.new(nil)
          yielded = :not_called

          response.process(controller) { |result| yielded = result }

          assert_nil yielded
        end

        test "process sets flash before yielding" do
          controller = MockController.new
          response = Null.new("result")
          response.with_flash([["Processed", :notice]])
          flash_during_yield = nil

          response.process(controller) do |_result|
            flash_during_yield = controller.flash[:notice]
          end

          assert_equal "Processed", flash_during_yield
        end

        test "result is accessible via attr_reader" do
          response = Null.new(42)

          assert_respond_to response, :result
          assert_equal 42, response.result
        end
      end
    end
  end
end
