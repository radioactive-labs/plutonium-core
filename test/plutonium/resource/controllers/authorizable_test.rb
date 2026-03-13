# frozen_string_literal: true

require "test_helper"

class Plutonium::Resource::Controllers::AuthorizableTest < ActiveSupport::TestCase
  class TestController
    # Stub Rails controller class methods needed by the modules
    def self.authorize(*, **) = nil
    def self.helper_method(*) = nil
    def self.after_action(*, **) = nil
    def self.skip_after_action(*, **) = nil
    def self.attr_writer(*) = nil
    def self.attr_reader(*) = nil
    def self.protected(*) = nil

    include Plutonium::Core::Controllers::Authorizable
    include Plutonium::Resource::Controllers::Authorizable

    attr_accessor :scoped_to_entity_value, :parent_value, :nested_association_value

    def scoped_to_entity?
      scoped_to_entity_value
    end

    def set_scoped_entity(entity)
      @current_scoped_entity = entity
    end

    def current_parent
      parent_value
    end

    def current_nested_association
      nested_association_value
    end
  end

  setup do
    @controller = TestController.new
    @controller.scoped_to_entity_value = false
  end

  test "current_policy_context includes entity_scope from base" do
    entity = Object.new
    @controller.scoped_to_entity_value = true
    @controller.set_scoped_entity(entity)
    @controller.parent_value = nil
    @controller.nested_association_value = nil

    context = @controller.send(:current_policy_context)

    assert_equal entity, context[:entity_scope]
  end

  test "current_policy_context includes parent and parent_association" do
    parent = Object.new
    association = :comments
    @controller.parent_value = parent
    @controller.nested_association_value = association

    context = @controller.send(:current_policy_context)

    assert_equal parent, context[:parent]
    assert_equal association, context[:parent_association]
  end

  test "current_policy_context merges all context keys" do
    entity = Object.new
    parent = Object.new
    association = :comments
    @controller.scoped_to_entity_value = true
    @controller.set_scoped_entity(entity)
    @controller.parent_value = parent
    @controller.nested_association_value = association

    context = @controller.send(:current_policy_context)

    assert_equal entity, context[:entity_scope]
    assert_equal parent, context[:parent]
    assert_equal association, context[:parent_association]
    assert_equal 3, context.size
  end
end
