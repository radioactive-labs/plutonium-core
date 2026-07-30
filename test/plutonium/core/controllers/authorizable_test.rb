# frozen_string_literal: true

require "test_helper"

class Plutonium::Core::Controllers::AuthorizableTest < ActiveSupport::TestCase
  class TestController
    # Stub Rails controller class methods needed by the module
    def self.authorize(*, **) = nil
    def self.helper_method(*) = nil

    include Plutonium::Core::Controllers::Authorizable

    attr_accessor :scoped_to_entity_value

    def scoped_to_entity?
      scoped_to_entity_value
    end

    def set_scoped_entity(entity)
      @current_scoped_entity = entity
    end
  end

  setup do
    @controller = TestController.new
  end

  test "entity_scope_for_authorize returns nil when not scoped to entity" do
    @controller.scoped_to_entity_value = false
    @controller.set_scoped_entity(Object.new)

    result = @controller.send(:entity_scope_for_authorize)

    assert_nil result
  end

  test "entity_scope_for_authorize returns entity when scoped and entity is set" do
    entity = Object.new
    @controller.scoped_to_entity_value = true
    @controller.set_scoped_entity(entity)

    result = @controller.send(:entity_scope_for_authorize)

    assert_equal entity, result
  end

  test "entity_scope_for_authorize returns nil when scoped but entity not yet set" do
    # This is the key scenario: during fetch_current_scoped_entity,
    # @current_scoped_entity hasn't been assigned yet
    @controller.scoped_to_entity_value = true

    result = @controller.send(:entity_scope_for_authorize)

    assert_nil result
  end

  test "entity_scope_for_authorize uses instance variable directly" do
    # Verify that entity_scope_for_authorize reads @current_scoped_entity directly
    # rather than calling current_scoped_entity method (which could cause circular dependency)
    entity = Object.new
    @controller.scoped_to_entity_value = true
    @controller.set_scoped_entity(entity)

    # Define current_scoped_entity that would raise if called
    @controller.define_singleton_method(:current_scoped_entity) do
      raise "Should not be called - would cause circular dependency!"
    end

    # This should NOT raise - it should read the instance variable directly
    result = @controller.send(:entity_scope_for_authorize)

    assert_equal entity, result
  end

  test "current_policy_context includes entity_scope" do
    entity = Object.new
    @controller.scoped_to_entity_value = true
    @controller.set_scoped_entity(entity)

    context = @controller.send(:current_policy_context)

    assert_equal({entity_scope: entity}, context)
  end

  test "current_policy_context returns nil entity_scope when not scoped" do
    @controller.scoped_to_entity_value = false

    context = @controller.send(:current_policy_context)

    assert_equal({entity_scope: nil}, context)
  end

  test "authorized_resource_scope merges current_policy_context into options" do
    entity = Object.new
    @controller.scoped_to_entity_value = true
    @controller.set_scoped_entity(entity)

    # Track what authorized_scope receives
    captured_options = nil
    @controller.define_singleton_method(:authorized_scope) do |relation, **options|
      captured_options = options
      relation
    end

    @controller.define_singleton_method(:authorization_namespace) { nil }

    @controller.send(:authorized_resource_scope, User, relation: User.all)

    assert_equal entity, captured_options[:context][:entity_scope]
  end

  test "authorized_resource_scope passes policy context when no explicit context given" do
    entity = Object.new
    @controller.scoped_to_entity_value = true
    @controller.set_scoped_entity(entity)

    captured_options = nil
    @controller.define_singleton_method(:authorized_scope) do |relation, **options|
      captured_options = options
      relation
    end

    @controller.define_singleton_method(:authorization_namespace) { nil }

    @controller.send(:authorized_resource_scope, User, relation: User.all)

    assert_equal({entity_scope: entity}, captured_options[:context])
  end

  test "authorized_resource_scope deep merges caller context with policy context" do
    entity = Object.new
    @controller.scoped_to_entity_value = true
    @controller.set_scoped_entity(entity)

    captured_options = nil
    @controller.define_singleton_method(:authorized_scope) do |relation, **options|
      captured_options = options
      relation
    end

    @controller.define_singleton_method(:authorization_namespace) { nil }

    @controller.send(:authorized_resource_scope, User, relation: User.all, context: {custom_key: "value"})

    assert_equal entity, captured_options[:context][:entity_scope]
    assert_equal "value", captured_options[:context][:custom_key]
  end

  # Unlike TestController above, this one does NOT stub `authorize`, so the real
  # ActionPolicy authorization_targets are registered and authorization_context
  # is built for real.
  class ContextTestController
    def self.helper_method(*) = nil

    include Plutonium::Core::Controllers::Authorizable

    attr_accessor :current_user

    def scoped_to_entity? = true

    def set_scoped_entity(entity)
      @current_scoped_entity = entity
    end
  end

  test "authorization_context is memoized with a nil entity_scope while the entity resolves" do
    controller = ContextTestController.new
    controller.current_user = Object.new

    # The window inside fetch_current_scoped_entity: the entity's own read? check
    # builds the context before @current_scoped_entity is assigned.
    assert_nil controller.authorization_context[:entity_scope]

    controller.set_scoped_entity(Object.new)

    # Still stale - ActionPolicy memoizes for the whole request.
    assert_nil controller.authorization_context[:entity_scope]
  end

  test "reset_authorization_context! rebuilds the context with the resolved entity_scope" do
    controller = ContextTestController.new
    controller.current_user = Object.new
    entity = Object.new

    assert_nil controller.authorization_context[:entity_scope]

    controller.set_scoped_entity(entity)
    controller.send(:reset_authorization_context!)

    assert_equal entity, controller.authorization_context[:entity_scope]
  end

  test "reset_authorization_context! preserves the rest of the context" do
    controller = ContextTestController.new
    user = Object.new
    controller.current_user = user

    controller.authorization_context
    controller.send(:reset_authorization_context!)

    assert_equal user, controller.authorization_context[:user]
  end

  # --- ActionPolicy contract -------------------------------------------------
  #
  # reset_authorization_context! works by clearing ActionPolicy's memo ivar
  # directly - the gem exposes no public API for invalidating it. That couples us
  # to a private internal, and the failure mode is silent: if the ivar moves, the
  # reset becomes a no-op, entity_scope goes back to nil for every bare
  # policy_for / allowed_to? / authorized_scope, and default_relation_scope
  # quietly stops applying tenant scoping (it falls through to the unscoped
  # `else` branch). No exception, no test failure elsewhere - just a leak.
  #
  # These tests pin the internal so a gem upgrade fails here instead.

  test "ActionPolicy memoizes the context into the ivar reset_authorization_context! clears" do
    controller = ContextTestController.new
    controller.current_user = Object.new

    before = controller.instance_variables
    built = controller.authorization_context
    memo_ivars = (controller.instance_variables - before).select do |ivar|
      controller.instance_variable_get(ivar) == built
    end

    assert_equal [:@_authorization_context], memo_ivars,
      "ActionPolicy's authorization context memo moved. reset_authorization_context! " \
      "clears @_authorization_context and is now a silent no-op - update it to clear #{memo_ivars.inspect}."
  end

  test "authorization_context resolves to the implementation reset_authorization_context! targets" do
    # ActionPolicy defines authorization_context twice, over *different* ivars:
    #   ActionPolicy::Behaviour            -> @_authorization_context  (wins today)
    #   ActionPolicy::Behaviours::PolicyFor -> @authorization_context
    # Behaviour includes PolicyFor and then redefines the method, so Behaviour's
    # version wins. If that ever inverts, our reset would clear the dead ivar.
    owner = ContextTestController.instance_method(:authorization_context).owner

    assert_equal ActionPolicy::Behaviour, owner,
      "authorization_context is now served by #{owner}, which may memoize into a different ivar " \
      "than the one reset_authorization_context! clears."
  end

  test "no instance variable retains the stale context after a reset" do
    # Generic backstop: catches a second/duplicated memo that the reset misses,
    # without depending on any ivar name.
    controller = ContextTestController.new
    controller.current_user = Object.new

    stale = controller.authorization_context
    controller.set_scoped_entity(Object.new)
    controller.send(:reset_authorization_context!)

    retained = controller.instance_variables.select do |ivar|
      controller.instance_variable_get(ivar) == stale
    end

    assert_empty retained,
      "#{retained.inspect} still holds the pre-reset authorization context; a bare policy_for would reuse it."
  end
end
