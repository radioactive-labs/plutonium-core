# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Interaction
    module Response
      class FileTest < ActiveSupport::TestCase
        class MockController
          attr_reader :flash, :send_file_calls

          def initialize
            @flash = {}
            @send_file_calls = []
          end

          # send_file receives path + options hash as positional args
          def send_file(*args)
            path = args.first
            options = args.last.is_a?(Hash) ? args.last : {}
            @send_file_calls << {path: path, options: options}
          end
        end

        test "inherits from Base" do
          response = File.new("/path/to/file")

          assert_kind_of Base, response
        end

        test "execute calls send_file with path" do
          controller = MockController.new
          response = File.new("/path/to/document.pdf")

          response.process(controller)

          assert_equal 1, controller.send_file_calls.size
          assert_equal "/path/to/document.pdf", controller.send_file_calls.first[:path]
        end

        test "execute passes options to send_file" do
          controller = MockController.new
          response = File.new("/path/to/file.csv", filename: "export.csv", type: "text/csv")

          response.process(controller)

          call = controller.send_file_calls.first
          assert_equal "export.csv", call[:options][:filename]
          assert_equal "text/csv", call[:options][:type]
        end

        test "execute passes disposition option" do
          controller = MockController.new
          response = File.new("/tmp/report.pdf", disposition: "inline")

          response.process(controller)

          assert_equal "inline", controller.send_file_calls.first[:options][:disposition]
        end

        test "process sets flash before sending file" do
          controller = MockController.new
          response = File.new("/path/to/file")
          response.with_flash([["Download started", :notice]])

          response.process(controller)

          assert_equal "Download started", controller.flash[:notice]
          assert_equal 1, controller.send_file_calls.size
        end
      end
    end
  end
end
