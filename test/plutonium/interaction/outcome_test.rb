require "test_helper"
require "plutonium/interaction/outcome"

module Plutonium
  module Interaction
    class OutcomeTest < Minitest::Test
      def test_success
        success = Success.new("test value")
        assert success.success?
        refute success.failure?
        assert_equal "test value", success.value
      end

      def test_failure
        errors = ["Error 1", "Error 2"]
        failure = Failure.new(errors)
        assert failure.failure?
        refute failure.success?
        assert_equal errors, failure.errors
      end

      def test_with_message
        success = Success.new("test").with_message("Success message", :notice)
        assert_equal [["Success message", :notice]], success.messages
      end

      def test_success_with_response
        redirect_response = Response::Redirect.new("/some/path")
        success = Success.new("test value").with_response(redirect_response)
        assert_equal redirect_response, success.to_response
        assert_equal "test value", success.value
      end

      def test_success_and_then
        result = Success.new(1)
          .and_then { |value| Success.new(value + 1) }
          .and_then { |value| Success.new(value * 2) }
        assert_equal 4, result.value
      end

      def test_failure_and_then
        initial_failure = Failure.new(["Initial error"])
        result = initial_failure
          .and_then { |_| Success.new("This shouldn't be reached") }
          .and_then { |_| Success.new("Nor this") }
        assert_equal initial_failure, result
      end

      def test_success_to_response_with_explicit_response
        redirect_response = Response::Redirect.new("/some/path")
        success = Success.new("test value").with_response(redirect_response)
        assert_equal redirect_response, success.to_response
      end

      def test_success_to_response_with_default_response
        success = Success.new("test value")
        assert_instance_of Response::Null, success.to_response
        assert_equal "test value", success.to_response.result
      end

      def test_success_to_response_with_messages
        success = Success.new("test value")
          .with_message("Message 1", :notice)
          .with_message("Message 2", :alert)
        response = success.to_response
        assert_equal [["Message 1", :notice], ["Message 2", :alert]], response.flash
      end

      def test_success_chaining_with_response_and_message
        result = Success.new(1)
          .and_then { |value| Success.new(value * 2) }
          .with_response(Response::Redirect.new("/result"))
          .with_message("Operation successful", :notice)

        assert_equal 2, result.value
        assert_instance_of Response::Redirect, result.to_response
        assert_equal [["Operation successful", :notice]], result.messages
      end

      def test_failure_with_response
        failure = Failure.new(["Error"])
        redirect_response = Response::Redirect.new("/error")
        result = failure.with_response(redirect_response)
        assert_equal failure, result
        assert_nil failure.instance_variable_get(:@response)
      end

      def test_failure_to_response
        failure = Failure.new(["Error"])
        assert_raises(NotImplementedError) { failure.to_response }
      end

      def test_success_with_response_resets_to_response_cache
        success = Success.new("test value")
        initial_response = success.to_response
        assert_instance_of Response::Null, initial_response

        new_response = Response::Redirect.new("/new/path")
        success.with_response(new_response)
        assert_equal new_response, success.to_response
      end
    end
  end
end
