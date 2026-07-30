# frozen_string_literal: true

require "test_helper"

class Plutonium::Core::Controllers::EntityScopingTest < ActiveSupport::TestCase
  # Stands in for the portal engine. A Symbol strategy lets us drive
  # fetch_current_scoped_entity without a real request/route.
  class TestEngine
    def scoped_to_entity? = true

    def scoped_entity_strategy = :lookup_entity
  end

  class TestController
    def self.helper_method(*) = nil

    def self.before_action(*, **) = nil

    include Plutonium::Core::Controllers::Authorizable
    include Plutonium::Core::Controllers::EntityScoping

    attr_accessor :current_user, :entity
    attr_reader :context_seen_during_lookup

    def current_engine = @current_engine ||= TestEngine.new

    def current_package = nil

    private

    # Simulates the `authorize! scoped_entity, to: :read?` that the :path strategy
    # performs while @current_scoped_entity is still nil - this is what builds and
    # memoizes ActionPolicy's authorization context.
    def lookup_entity
      @context_seen_during_lookup = authorization_context
      entity
    end
  end

  setup do
    @controller = TestController.new
    @controller.current_user = Object.new
    @controller.entity = Object.new
  end

  test "current_scoped_entity returns the resolved entity" do
    assert_equal @controller.entity, @controller.send(:current_scoped_entity)
  end

  test "the authorization built during lookup sees a nil entity_scope" do
    @controller.send(:current_scoped_entity)

    assert_nil @controller.context_seen_during_lookup[:entity_scope]
  end

  test "current_scoped_entity clears the stale authorization context memo" do
    @controller.send(:current_scoped_entity)

    assert_equal @controller.entity, @controller.authorization_context[:entity_scope]
  end

  test "policy_for without an explicit context sees the entity_scope" do
    @controller.send(:current_scoped_entity)

    # This is the picker path: policy_for(record: SomeClass) with no context:,
    # which falls back to the memoized authorization_context.
    policy = @controller.send(:policy_for, record: Object.new, with: Class.new(Plutonium::Resource::Policy))

    assert_equal @controller.entity, policy.entity_scope
  end

  test "current_scoped_entity memoizes and does not re-resolve" do
    calls = 0
    @controller.define_singleton_method(:lookup_entity) do
      calls += 1
      entity
    end

    3.times { @controller.send(:current_scoped_entity) }

    assert_equal 1, calls
  end

  test "current_scoped_entity returns nil when there is no current_user" do
    @controller.current_user = nil

    assert_nil @controller.send(:current_scoped_entity)
  end

  test "a strategy that resolves nothing leaves the authorization context memo intact" do
    @controller.entity = nil

    assert_nil @controller.send(:current_scoped_entity)

    # The memo built during lookup already says `entity_scope: nil`, which is
    # correct, so it must survive. nil is not memoized into
    # @current_scoped_entity, so an unconditional reset would re-resolve and
    # rebuild the context on every call - and current_scoped_entity is a
    # helper_method that views call repeatedly.
    assert_same @controller.context_seen_during_lookup, @controller.authorization_context
  end
end
