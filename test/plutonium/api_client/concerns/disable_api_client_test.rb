# frozen_string_literal: true

require "test_helper"

module Plutonium
  module ApiClient
    module Concerns
      class DisableApiClientTest < ActiveSupport::TestCase
        # Stub for presents DSL method
        module PresentsDSL
          def self.included(base)
            base.extend(ClassMethods)
          end

          module ClassMethods
            def presents(**options)
              # no-op for testing
            end

            def attribute(*args, **kwargs)
              # no-op for testing
            end

            def validates(*args, **kwargs)
              # no-op for testing
            end
          end
        end

        # Mock classes for testing
        class MockApiClient
          attr_reader :login

          def initialize(login:)
            @login = login
          end
        end

        class MockRodauthInstance
          attr_reader :close_account_calls
          attr_accessor :should_raise

          def initialize
            @close_account_calls = []
            @should_raise = false
          end

          def close_account(account_login:)
            raise "Account not found" if @should_raise

            @close_account_calls << {account_login: account_login}
            nil
          end
        end

        class MockOutcome
          attr_reader :record, :message

          def initialize(record)
            @record = record
          end

          def with_message(msg)
            @message = msg
            self
          end
        end

        class MockFailure
          attr_reader :errors

          def initialize(errors)
            @errors = errors
          end
        end

        # Test interaction
        class TestInteraction
          include PresentsDSL
          include DisableApiClient

          attr_accessor :resource

          def initialize(resource:, rodauth_instance:)
            @resource = resource
            @rodauth_instance_mock = rodauth_instance
          end

          def succeed(record)
            MockOutcome.new(record)
          end

          def failed(errors)
            MockFailure.new(errors)
          end

          private

          def rodauth_name
            :test_api_client
          end

          def rodauth_instance
            @rodauth_instance_mock
          end

          # Expose for testing
          public :success_message
        end

        def setup
          @rodauth_instance = MockRodauthInstance.new
        end

        test "execute calls rodauth close_account with login" do
          api_client = MockApiClient.new(login: "test-app")

          interaction = TestInteraction.new(
            resource: api_client,
            rodauth_instance: @rodauth_instance
          )

          interaction.execute

          assert_equal 1, @rodauth_instance.close_account_calls.size
          assert_equal "test-app", @rodauth_instance.close_account_calls.first[:account_login]
        end

        test "execute returns success with message" do
          api_client = MockApiClient.new(login: "my-client")

          interaction = TestInteraction.new(
            resource: api_client,
            rodauth_instance: @rodauth_instance
          )

          result = interaction.execute

          assert_kind_of MockOutcome, result
          assert_equal api_client, result.record
          assert_match(/my-client/, result.message)
        end

        test "execute returns failure when exception raised" do
          api_client = MockApiClient.new(login: "test-app")
          @rodauth_instance.should_raise = true

          interaction = TestInteraction.new(
            resource: api_client,
            rodauth_instance: @rodauth_instance
          )

          result = interaction.execute

          assert_kind_of MockFailure, result
          assert_match(/Account not found/, result.errors[:base])
        end

        test "success_message returns formatted message with login" do
          api_client = MockApiClient.new(login: "my-app")

          interaction = TestInteraction.new(
            resource: api_client,
            rodauth_instance: @rodauth_instance
          )

          message = interaction.success_message("my-app")

          assert_equal "API client 'my-app' has been disabled", message
        end

        test "rodauth_name raises NotImplementedError in base" do
          klass = Class.new do
            include PresentsDSL
            include DisableApiClient

            attr_accessor :resource
          end

          interaction = klass.new

          assert_raises(NotImplementedError) do
            interaction.send(:rodauth_name)
          end
        end
      end
    end
  end
end
