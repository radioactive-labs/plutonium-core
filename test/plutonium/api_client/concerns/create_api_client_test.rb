# frozen_string_literal: true

require "test_helper"
require "ostruct"

module Plutonium
  module ApiClient
    module Concerns
      class CreateApiClientTest < ActiveSupport::TestCase
        # Stub for presents DSL method - must be defined before test classes
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
          attr_reader :id, :login

          def initialize(id:, login:)
            @id = id
            @login = login
          end

          def self.model_name
            OpenStruct.new(singular: "mock_api_client")
          end
        end

        class MockEntity
          attr_reader :id

          def initialize(id)
            @id = id
          end

          def self.model_name
            OpenStruct.new(singular: "mock_entity")
          end
        end

        class MockMembership
          class << self
            attr_accessor :created_attrs
          end

          def self.create!(attrs)
            @created_attrs = attrs
            new
          end
        end

        class MockRodauthInstance
          attr_reader :create_account_calls

          def initialize
            @create_account_calls = []
          end

          def create_account(login:, password:)
            @create_account_calls << {login: login, password: password}
            nil # Rodauth internal_request returns nil
          end
        end

        class MockController
          attr_accessor :current_scoped_entity, :current_parent
        end

        class MockViewContext
          attr_reader :controller

          def initialize(controller)
            @controller = controller
          end
        end

        # Mock outcome for testing
        class MockOutcome
          attr_reader :record

          def initialize(record)
            @record = record
          end

          def with_render_response(page)
            self
          end
        end

        class MockFailure
          attr_reader :errors

          def initialize(errors)
            @errors = errors
          end
        end

        # Mock API client class with find_by!
        class MockApiClientClass
          attr_accessor :client_to_return

          def find_by!(login:)
            @client_to_return || raise(ActiveRecord::RecordNotFound, "not found")
          end

          def model_name
            OpenStruct.new(singular: "mock_api_client")
          end
        end

        # Test interaction without entity scoping
        class BasicTestInteraction
          include PresentsDSL
          include CreateApiClient

          attr_accessor :view_context, :login, :attributes

          def initialize(view_context:, login:, rodauth_instance:, api_client_class:)
            @view_context = view_context
            @login = login
            @rodauth_instance_mock = rodauth_instance
            @api_client_class_mock = api_client_class
            @attributes = {}
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

          def api_client_class
            @api_client_class_mock
          end

          def rodauth_instance
            @rodauth_instance_mock
          end

          # Expose private methods for testing
          public :generate_secure_password, :entity_scoped_api_client?,
            :entity_foreign_key, :api_client_foreign_key
        end

        # Test interaction with entity scoping
        class EntityScopedTestInteraction < BasicTestInteraction
          attr_accessor :entity_class_mock, :membership_class_mock, :role_value, :scoped_entity_id_override

          def entity_class
            @entity_class_mock
          end

          def membership_class
            @membership_class_mock
          end

          def role
            @role_value
          end

          def scoped_entity_id
            @scoped_entity_id_override
          end

          # Expose for testing
          public :create_membership!
        end

        def setup
          @controller = MockController.new
          @view_context = MockViewContext.new(@controller)
          @rodauth_instance = MockRodauthInstance.new
          @api_client_class = MockApiClientClass.new
          MockMembership.created_attrs = nil
        end

        # Password generation tests
        test "generate_secure_password returns a base64 string" do
          interaction = BasicTestInteraction.new(
            view_context: @view_context,
            login: "test-app",
            rodauth_instance: @rodauth_instance,
            api_client_class: @api_client_class
          )

          password = interaction.generate_secure_password

          assert_kind_of String, password
          assert password.length >= 32, "Password should be at least 32 characters"
        end

        test "generate_secure_password returns unique values" do
          interaction = BasicTestInteraction.new(
            view_context: @view_context,
            login: "test-app",
            rodauth_instance: @rodauth_instance,
            api_client_class: @api_client_class
          )

          passwords = 10.times.map { interaction.generate_secure_password }

          assert_equal 10, passwords.uniq.size, "All generated passwords should be unique"
        end

        # Entity scoping tests
        test "entity_scoped_api_client? returns false when no entity_class" do
          interaction = BasicTestInteraction.new(
            view_context: @view_context,
            login: "test-app",
            rodauth_instance: @rodauth_instance,
            api_client_class: @api_client_class
          )

          refute interaction.entity_scoped_api_client?
        end

        test "entity_scoped_api_client? returns false when no membership_class" do
          interaction = EntityScopedTestInteraction.new(
            view_context: @view_context,
            login: "test-app",
            rodauth_instance: @rodauth_instance,
            api_client_class: @api_client_class
          )
          interaction.entity_class_mock = MockEntity
          interaction.membership_class_mock = nil
          interaction.scoped_entity_id_override = 1

          refute interaction.entity_scoped_api_client?
        end

        test "entity_scoped_api_client? returns false when no scoped_entity_id" do
          interaction = EntityScopedTestInteraction.new(
            view_context: @view_context,
            login: "test-app",
            rodauth_instance: @rodauth_instance,
            api_client_class: @api_client_class
          )
          interaction.entity_class_mock = MockEntity
          interaction.membership_class_mock = MockMembership
          interaction.scoped_entity_id_override = nil

          refute interaction.entity_scoped_api_client?
        end

        test "entity_scoped_api_client? returns true when all conditions met" do
          interaction = EntityScopedTestInteraction.new(
            view_context: @view_context,
            login: "test-app",
            rodauth_instance: @rodauth_instance,
            api_client_class: @api_client_class
          )
          interaction.entity_class_mock = MockEntity
          interaction.membership_class_mock = MockMembership
          interaction.scoped_entity_id_override = 1

          assert interaction.entity_scoped_api_client?
        end

        # Foreign key generation tests
        test "entity_foreign_key generates correct key from entity class" do
          interaction = EntityScopedTestInteraction.new(
            view_context: @view_context,
            login: "test-app",
            rodauth_instance: @rodauth_instance,
            api_client_class: @api_client_class
          )
          interaction.entity_class_mock = MockEntity

          assert_equal :mock_entity_id, interaction.entity_foreign_key
        end

        test "api_client_foreign_key generates correct key from api client class" do
          interaction = BasicTestInteraction.new(
            view_context: @view_context,
            login: "test-app",
            rodauth_instance: @rodauth_instance,
            api_client_class: @api_client_class
          )

          assert_equal :mock_api_client_id, interaction.api_client_foreign_key
        end

        # Execute tests
        test "execute calls rodauth create_account with login and password" do
          api_client = MockApiClient.new(id: 1, login: "test-app")
          @api_client_class.client_to_return = api_client

          interaction = BasicTestInteraction.new(
            view_context: @view_context,
            login: "test-app",
            rodauth_instance: @rodauth_instance,
            api_client_class: @api_client_class
          )

          interaction.execute

          assert_equal 1, @rodauth_instance.create_account_calls.size
          call = @rodauth_instance.create_account_calls.first
          assert_equal "test-app", call[:login]
          assert_kind_of String, call[:password]
          assert call[:password].length >= 32
        end

        test "execute returns failure when account not found" do
          @api_client_class.client_to_return = nil # Will raise RecordNotFound

          interaction = BasicTestInteraction.new(
            view_context: @view_context,
            login: "test-app",
            rodauth_instance: @rodauth_instance,
            api_client_class: @api_client_class
          )

          result = interaction.execute

          assert_kind_of MockFailure, result
          assert_match(/Failed to create account/, result.errors[:login])
        end

        test "create_membership creates membership with correct attributes" do
          api_client = MockApiClient.new(id: 99, login: "test-app")

          interaction = EntityScopedTestInteraction.new(
            view_context: @view_context,
            login: "test-app",
            rodauth_instance: @rodauth_instance,
            api_client_class: @api_client_class
          )
          interaction.entity_class_mock = MockEntity
          interaction.membership_class_mock = MockMembership
          interaction.scoped_entity_id_override = 42
          interaction.role_value = "admin"

          interaction.create_membership!(api_client)

          assert_not_nil MockMembership.created_attrs
          assert_equal 42, MockMembership.created_attrs[:mock_entity_id]
          assert_equal 99, MockMembership.created_attrs[:mock_api_client_id]
          assert_equal "admin", MockMembership.created_attrs[:role]
        end

        test "create_membership excludes role when nil" do
          api_client = MockApiClient.new(id: 99, login: "test-app")

          interaction = EntityScopedTestInteraction.new(
            view_context: @view_context,
            login: "test-app",
            rodauth_instance: @rodauth_instance,
            api_client_class: @api_client_class
          )
          interaction.entity_class_mock = MockEntity
          interaction.membership_class_mock = MockMembership
          interaction.scoped_entity_id_override = 42
          interaction.role_value = nil

          interaction.create_membership!(api_client)

          refute MockMembership.created_attrs.key?(:role)
        end

        test "execute does not create membership when not entity scoped" do
          api_client = MockApiClient.new(id: 1, login: "test-app")
          @api_client_class.client_to_return = api_client

          interaction = BasicTestInteraction.new(
            view_context: @view_context,
            login: "test-app",
            rodauth_instance: @rodauth_instance,
            api_client_class: @api_client_class
          )

          interaction.execute

          assert_nil MockMembership.created_attrs
        end

        # Required method tests
        test "rodauth_name raises NotImplementedError in base" do
          klass = Class.new do
            include PresentsDSL
            include CreateApiClient

            attr_accessor :view_context
          end

          interaction = klass.new

          assert_raises(NotImplementedError) do
            interaction.send(:rodauth_name)
          end
        end

        test "api_client_class raises NotImplementedError in base" do
          klass = Class.new do
            include PresentsDSL
            include CreateApiClient

            attr_accessor :view_context
          end

          interaction = klass.new

          assert_raises(NotImplementedError) do
            interaction.send(:api_client_class)
          end
        end

        # CredentialsPage tests
        test "CredentialsPage initializes with login and password" do
          page = CreateApiClient::CredentialsPage.new(
            login: "my-app",
            password: "secret123"
          )

          assert_equal "my-app", page.instance_variable_get(:@login)
          assert_equal "secret123", page.instance_variable_get(:@password)
          assert_nil page.instance_variable_get(:@parent)
        end

        test "CredentialsPage initializes with optional parent" do
          parent = MockEntity.new(1)
          page = CreateApiClient::CredentialsPage.new(
            login: "my-app",
            password: "secret123",
            parent: parent
          )

          assert_equal parent, page.instance_variable_get(:@parent)
        end

        test "CredentialsPage success_title returns default message" do
          page = CreateApiClient::CredentialsPage.new(
            login: "my-app",
            password: "secret123"
          )

          assert_equal "API Client Created Successfully", page.send(:success_title)
        end
      end
    end
  end
end
