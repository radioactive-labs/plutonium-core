# frozen_string_literal: true

require "test_helper"

class Plutonium::Resource::KanbanPolicyTest < Minitest::Test
  def setup
    @user = User.create!(email: "kanban_test_#{SecureRandom.hex(4)}@example.com", status: :verified)
  end

  def teardown
    User.delete_all
  end

  def make_policy(policy_class = Plutonium::Resource::Policy)
    policy_class.new(record: Blogging::Post, user: @user, entity_scope: nil)
  end

  # kanban_move? delegates to update? by default
  def test_kanban_move_delegates_to_update_when_update_is_true
    policy = make_policy
    policy.define_singleton_method(:update?) { true }
    assert policy.kanban_move?
  end

  def test_kanban_move_delegates_to_update_when_update_is_false
    policy = make_policy
    policy.define_singleton_method(:update?) { false }
    refute policy.kanban_move?
  end

  # A subclass can override kanban_move? independently of update?
  def test_kanban_move_can_be_overridden_independently_of_update
    custom_policy_class = Class.new(Plutonium::Resource::Policy) do
      def update? = false

      def kanban_move? = true
    end

    policy = make_policy(custom_policy_class)
    refute policy.update?
    assert policy.kanban_move?
  end
end
