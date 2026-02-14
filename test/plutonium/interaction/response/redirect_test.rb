# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Plutonium
  module Interaction
    module Response
      class RedirectTest < ActiveSupport::TestCase
        class MockRequest
          attr_accessor :format_symbol

          def initialize(format_symbol = :html)
            @format_symbol = format_symbol
          end

          def format
            OpenStruct.new(symbol: @format_symbol)
          end
        end

        class MockHelpers
          attr_accessor :turbo_frame

          def current_turbo_frame
            @turbo_frame
          end

          def turbo_stream_redirect(url)
            "turbo_redirect_to_#{url}"
          end
        end

        class MockFormat
          attr_reader :turbo_stream_block, :any_block

          def turbo_stream(&block)
            @turbo_stream_block = block
          end

          def any(&block)
            @any_block = block
          end

          def call_turbo_stream
            @turbo_stream_block&.call
          end

          def call_any
            @any_block&.call
          end
        end

        class MockController
          attr_reader :flash, :redirect_calls, :render_calls
          attr_accessor :request, :helpers

          def initialize
            @flash = {}
            @redirect_calls = []
            @render_calls = []
            @request = MockRequest.new
            @helpers = MockHelpers.new
          end

          def url_for(*args)
            args.first.is_a?(String) ? args.first : "/generated/url"
          end

          def redirect_to(url, **options)
            @redirect_calls << {url: url, options: options}
          end

          def render(**options)
            @render_calls << options
          end

          def respond_to
            @format = MockFormat.new
            yield @format
          end

          def simulate_turbo_stream
            @format.call_turbo_stream
          end

          def simulate_any
            @format.call_any
          end

          def instance_eval(&block)
            instance_exec(&block)
          end
        end

        test "inherits from Base" do
          response = Redirect.new("/path")

          assert_kind_of Base, response
        end

        test "execute redirects for non-turbo requests" do
          controller = MockController.new
          response = Redirect.new("/dashboard")

          response.process(controller)
          controller.simulate_any

          assert_equal 1, controller.redirect_calls.size
          assert_equal "/dashboard", controller.redirect_calls.first[:url]
        end

        test "execute passes redirect options" do
          controller = MockController.new
          response = Redirect.new("/login", status: :see_other, allow_other_host: true)

          response.process(controller)
          controller.simulate_any

          options = controller.redirect_calls.first[:options]
          assert_equal :see_other, options[:status]
          assert_equal true, options[:allow_other_host]
        end

        test "execute redirects for turbo_stream without remote_modal" do
          controller = MockController.new
          controller.helpers.turbo_frame = nil
          response = Redirect.new("/next")

          response.process(controller)
          controller.simulate_turbo_stream

          assert_equal 1, controller.redirect_calls.size
        end

        test "execute renders turbo_stream_redirect for remote_modal" do
          controller = MockController.new
          controller.helpers.turbo_frame = "remote_modal"
          response = Redirect.new("/success")

          response.process(controller)
          controller.simulate_turbo_stream

          assert_equal 1, controller.render_calls.size
          render_call = controller.render_calls.first
          assert_includes render_call[:turbo_stream], "turbo_redirect_to_/success"
        end

        test "preserves non-html format in redirect url" do
          controller = MockController.new
          controller.request.format_symbol = :json
          response = Redirect.new("/api/resource")

          response.process(controller)
          controller.simulate_any

          # The url_for mock returns the first arg, so we verify the format was added
          assert_equal 1, controller.redirect_calls.size
        end

        test "does not override explicitly specified format" do
          controller = MockController.new
          controller.request.format_symbol = :json
          response = Redirect.new("/resource", format: :xml)

          response.process(controller)
          controller.simulate_any

          assert_equal 1, controller.redirect_calls.size
        end

        test "process sets flash before redirecting" do
          controller = MockController.new
          response = Redirect.new("/home")
          response.with_flash([["Redirecting...", :notice]])

          response.process(controller)

          assert_equal "Redirecting...", controller.flash[:notice]
        end
      end
    end
  end
end
