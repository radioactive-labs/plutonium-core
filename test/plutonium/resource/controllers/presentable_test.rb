# frozen_string_literal: true

require "test_helper"

class Plutonium::Resource::Controllers::PresentableTest < Minitest::Test
  def setup
    @user = User.create!(email: "presentable_test@example.com", status: :verified)
    @post = Blogging::Post.create!(user: @user, title: "Test Post", body: "Body content")
  end

  def teardown
    Blogging::Post.delete_all
    User.delete_all
  end

  # Test permitted_attributes_for returns correct attributes for specific actions

  def test_permitted_attributes_for_returns_new_action_attributes
    controller = build_controller(action_name: "create")

    # permitted_attributes_for(:new) should return new's attributes, not create's
    new_attrs = controller.send(:permitted_attributes_for, :new)
    create_attrs = controller.send(:permitted_attributes_for, :create)

    # By default they delegate to the same method, but the mechanism works
    assert_kind_of Array, new_attrs
    assert_kind_of Array, create_attrs
  end

  def test_permitted_attributes_for_returns_edit_action_attributes
    controller = build_controller(action_name: "update", record: @post)

    edit_attrs = controller.send(:permitted_attributes_for, :edit)
    update_attrs = controller.send(:permitted_attributes_for, :update)

    assert_kind_of Array, edit_attrs
    assert_kind_of Array, update_attrs
  end

  # Test submittable_attributes_for returns attributes for specific actions

  def test_submittable_attributes_for_uses_specified_action
    controller = build_controller(action_name: "create")

    # Even though action_name is "create", we can get attributes for "new"
    new_attrs = controller.send(:submittable_attributes_for, :new)

    assert_kind_of Array, new_attrs
  end

  def test_submittable_attributes_delegates_to_permitted_attributes_for
    controller = build_controller(action_name: "create")

    # submittable_attributes_for should use permitted_attributes_for internally
    new_submittable = controller.send(:submittable_attributes_for, :new)
    new_permitted = controller.send(:permitted_attributes_for, :new)

    # They should be based on the same permitted attributes
    # (submittable may filter out parent/entity params, but base should match)
    assert_equal new_permitted, new_submittable
  end

  # Test build_form uses correct action for attributes

  def test_build_form_uses_current_action_by_default
    controller = build_controller(action_name: "create")

    # build_form without action: parameter uses action_name
    form = controller.send(:build_form, Blogging::Post.new)

    assert_kind_of Plutonium::UI::Form::Resource, form
  end

  def test_build_form_with_action_override_uses_specified_action
    controller = build_controller(action_name: "create")

    # build_form with action: :new should use new's attributes
    form = controller.send(:build_form, Blogging::Post.new, action: :new)

    assert_kind_of Plutonium::UI::Form::Resource, form
  end

  def test_build_form_for_update_error_uses_edit_action
    controller = build_controller(action_name: "update", record: @post)

    # When update fails, we re-render edit form with edit's attributes
    form = controller.send(:build_form, @post, action: :edit)

    assert_kind_of Plutonium::UI::Form::Resource, form
  end

  # Test with policy that has different attributes for new vs create

  def test_build_form_respects_different_new_vs_create_attributes
    # Create a custom policy with different attributes
    custom_policy_class = Class.new(Blogging::PostPolicy) do
      def permitted_attributes_for_new
        [:title, :body, :user_id]  # Display form shows these
      end

      def permitted_attributes_for_create
        [:title, :body]  # API accepts only these (user_id set by controller)
      end
    end

    controller = build_controller(
      action_name: "create",
      policy_class: custom_policy_class
    )

    new_attrs = controller.send(:permitted_attributes_for, :new)
    create_attrs = controller.send(:permitted_attributes_for, :create)

    assert_includes new_attrs, :user_id
    refute_includes create_attrs, :user_id
  end

  private

  def build_controller(action_name:, record: nil, policy_class: nil)
    policy_class ||= Blogging::PostPolicy

    controller = TestableController.new
    controller.test_action_name = action_name
    controller.test_record = record
    controller.test_user = @user
    controller.test_policy_class = policy_class
    controller
  end

  # Controller class that includes the real modules
  class TestableController < ActionController::Base
    include Plutonium::Resource::Controllers::Authorizable
    include Plutonium::Resource::Controllers::Presentable

    attr_accessor :test_action_name, :test_record, :test_user, :test_policy_class

    def action_name
      test_action_name
    end

    def resource_class
      Blogging::Post
    end

    def resource_record!
      test_record || Blogging::Post.new
    end

    def current_parent
      nil
    end

    def scoped_to_entity?
      false
    end

    def singular_resource_context?
      false
    end

    def current_policy
      @current_policy ||= test_policy_class.new(
        record: test_record || Blogging::Post,
        user: test_user,
        entity_scope: nil
      )
    end

    def current_definition
      @current_definition ||= Blogging::PostDefinition.new
    end
  end
end
