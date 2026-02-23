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
end
