# frozen_string_literal: true

require "test_helper"

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
            Struct.new(:symbol).new(symbol: @format_symbol)
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

          # Rails' own check and its default, private on
          # ActionController::Redirecting. Tested for real below; here they only
          # have to let a relative URL through.
          def _enforce_open_redirect_protection(location, allow_other_host:)
            location
          end

          def _allow_other_host = false

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

        # A plain redirect_to is followed by fetch, and the page it lands on is
        # rendered into whatever frame submitted the form.
        test "execute renders turbo_stream_redirect for turbo_stream outside the modal" do
          controller = MockController.new
          controller.helpers.turbo_frame = nil
          response = Redirect.new("/next")

          response.process(controller)
          controller.simulate_turbo_stream

          assert_empty controller.redirect_calls
          assert_includes controller.render_calls.first[:turbo_stream], "turbo_redirect_to_/next"
        end

        test "a turbo_stream request redirects to the page, not a .turbo_stream URL" do
          controller = MockController.new
          controller.request.format_symbol = :turbo_stream
          def controller.url_for(*args) = (args.last.is_a?(Hash) && args.last[:format]) ? "/runs/1.#{args.last[:format]}" : "/runs/1"
          response = Redirect.new(:run)

          response.process(controller)
          controller.simulate_turbo_stream

          assert_includes controller.render_calls.first[:turbo_stream], "turbo_redirect_to_/runs/1"
          refute_includes controller.render_calls.first[:turbo_stream], ".turbo_stream"
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

        test "a fully-formed URL survives a non-html request" do
          controller = MockController.new
          controller.request.format_symbol = :turbo_stream
          # Real arity. The mock above takes *args, which is why appending a
          # format hash to a String target went unnoticed here while raising
          # ArgumentError against Rails' own url_for(options = nil).
          def controller.url_for(options = nil) = options.is_a?(String) ? options : "/generated/url"

          response = Redirect.new("http://example.test/admin/async_runs/1")

          response.process(controller)
          controller.simulate_any

          # Taken as given: there is nothing to merge a format into, and the
          # caller has already decided what the URL points at.
          assert_equal "http://example.test/admin/async_runs/1",
            controller.redirect_calls.first[:url]
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

        # A real controller, because the check under test is Rails' own.
        def turbo_stream_controller
          ::AdminPortal::PlutoniumController.new.tap do |controller|
            controller.set_request!(ActionDispatch::TestRequest.create(
              "HTTP_ACCEPT" => "text/vnd.turbo-stream.html", "HTTP_HOST" => "example.test"
            ))
            controller.set_response!(ActionDispatch::TestResponse.new)
          end
        end

        # turbo_stream_redirect is a client-side Turbo.visit, which navigates
        # to any host. It must be held to the same rule redirect_to is.
        test "a turbo_stream redirect to another host is refused" do
          assert_raises(ActionController::Redirecting::UnsafeRedirectError) do
            Redirect.new("https://evil.test/steal").process(turbo_stream_controller)
          end
        end

        test "a turbo_stream redirect to another host goes through with allow_other_host" do
          controller = turbo_stream_controller

          Redirect.new("https://partner.test/next", allow_other_host: true).process(controller)

          assert_includes controller.response.body, 'url="https://partner.test/next"'
        end

        test "a turbo_stream redirect within the app goes through" do
          controller = turbo_stream_controller

          Redirect.new("/admin/async_runs/1").process(controller)

          assert_includes controller.response.body, 'url="/admin/async_runs/1"'
        end

        # These are mattr_accessors, process-wide, so each is put back after.
        def with_redirect_config(controller, **settings)
          previous = settings.keys.to_h { |key| [key, controller.public_send(key)] }
          settings.each { |key, value| controller.public_send(:"#{key}=", value) }
          yield
        ensure
          previous.each { |key, value| controller.public_send(:"#{key}=", value) }
        end

        # redirect_to's default follows the app's setting, so the stream visit
        # must too: an app that opted out of the check is not held to it here.
        # On 8.1 action_on_open_redirect has the final say, covered below.
        test "a turbo_stream redirect to another host follows raise_on_open_redirects = false" do
          skip "action_on_open_redirect decides on Rails 8.1+" if ActionPack.gem_version >= Gem::Version.new("8.1")

          controller = turbo_stream_controller

          with_redirect_config(controller, raise_on_open_redirects: false) do
            Redirect.new("https://partner.test/next").process(controller)
          end

          assert_includes controller.response.body, 'url="https://partner.test/next"'
        end

        # From 8.1 the check itself resolves a nil allow_other_host, which is
        # what lets action_on_open_redirect log instead of raise.
        test "a turbo_stream redirect to another host is logged under action_on_open_redirect = :log" do
          skip "action_on_open_redirect is Rails 8.1+" if ActionPack.gem_version < Gem::Version.new("8.1")

          controller = turbo_stream_controller
          log = StringIO.new

          with_redirect_config(controller, raise_on_open_redirects: false, action_on_open_redirect: :log,
            logger: ActiveSupport::Logger.new(log)) do
            Redirect.new("https://partner.test/next").process(controller)
          end

          assert_includes controller.response.body, 'url="https://partner.test/next"'
          assert_match(/Open redirect to "https:\/\/partner.test\/next" detected/, log.string)
        end
      end
    end
  end
end
