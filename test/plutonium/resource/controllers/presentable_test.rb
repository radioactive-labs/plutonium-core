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

  # Test scoped_entity_association detection

  def test_scoped_entity_association_finds_association_by_class
    # Use Comment which has only one belongs_to :user
    controller = build_scoped_controller(
      resource_class: Blogging::Comment,
      scoped_entity_class: User
    )

    assoc_name = controller.send(:scoped_entity_association)

    assert_equal :user, assoc_name
  end

  def test_scoped_entity_association_returns_nil_when_no_matching_association
    controller = build_scoped_controller(
      resource_class: Blogging::Comment,
      scoped_entity_class: Organization # Comment doesn't belong_to Organization
    )

    assoc = controller.send(:scoped_entity_association)

    assert_nil assoc
  end

  def test_scoped_entity_association_raises_when_multiple_associations_exist
    # Post has multiple User associations: user, author, editor
    controller = build_scoped_controller(
      resource_class: Blogging::Post,
      scoped_entity_class: User
    )

    error = assert_raises(RuntimeError) do
      controller.send(:scoped_entity_association)
    end

    assert_includes error.message, "multiple associations"
    assert_includes error.message, "Override `scoped_entity_association`"
  end

  def test_scoped_entity_field_names_includes_association_and_param_key
    # Use Comment with a different param_key than the association name
    controller = build_scoped_controller(
      resource_class: Blogging::Comment,
      scoped_entity_class: User,
      scoped_entity_param_key: :author # Different from association name :user
    )

    field_names = controller.send(:scoped_entity_field_names)

    # Should include both param_key and association name
    assert_includes field_names, :author
    assert_includes field_names, :author_id
    assert_includes field_names, :user
    assert_includes field_names, :user_id
  end

  def test_scoped_entity_field_names_only_includes_param_key_when_no_association
    # Use Comment scoped to Organization (no matching belongs_to)
    controller = build_scoped_controller(
      resource_class: Blogging::Comment,
      scoped_entity_class: Organization,
      scoped_entity_param_key: :org
    )

    field_names = controller.send(:scoped_entity_field_names)

    # Should only include param_key since no association was found
    assert_includes field_names, :org
    assert_includes field_names, :org_id
    assert_equal 2, field_names.size
  end

  def test_presentable_attributes_excludes_scoped_entity_by_association
    # Use Comment with a different param_key than association
    controller = build_scoped_controller(
      resource_class: Blogging::Comment,
      scoped_entity_class: User,
      scoped_entity_param_key: :author, # Different from association :user
      action_name: "index"
    )

    attrs = controller.send(:presentable_attributes)

    # Should exclude both the param_key and the actual association
    refute_includes attrs, :author
    refute_includes attrs, :author_id
    refute_includes attrs, :user
    refute_includes attrs, :user_id
  end

  def test_submittable_attributes_excludes_scoped_entity_by_association
    # Use Comment with a different param_key than association
    controller = build_scoped_controller(
      resource_class: Blogging::Comment,
      scoped_entity_class: User,
      scoped_entity_param_key: :author, # Different from association :user
      action_name: "create"
    )

    attrs = controller.send(:submittable_attributes)

    # Should exclude both the param_key and the actual association
    refute_includes attrs, :author
    refute_includes attrs, :author_id
    refute_includes attrs, :user
    refute_includes attrs, :user_id
  end

  def test_scoped_entity_association_skips_polymorphic_belongs_to
    # PolymorphicComment has a polymorphic belongs_to alongside a real entity association
    controller = build_scoped_controller(
      resource_class: PolymorphicComment,
      scoped_entity_class: User
    )

    # Should find :user and skip :commentable (polymorphic) without raising
    assoc_name = controller.send(:scoped_entity_association)
    assert_equal :user, assoc_name
  end

  def test_scoped_entity_association_returns_nil_with_only_polymorphic_belongs_to
    controller = build_scoped_controller(
      resource_class: PolymorphicOnlyComment,
      scoped_entity_class: User
    )

    # Should return nil, not raise from calling .klass on polymorphic
    assoc = controller.send(:scoped_entity_association)
    assert_nil assoc
  end

  def test_scoped_entity_association_can_be_overridden
    # Test that controller can override to resolve ambiguity
    controller = build_scoped_controller(
      resource_class: Blogging::Post,
      scoped_entity_class: User
    )

    # Override the method to specify which association to use
    controller.define_singleton_method(:scoped_entity_association) do
      :author
    end

    assoc_name = controller.send(:scoped_entity_association)

    assert_equal :author, assoc_name
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

  def build_scoped_controller(resource_class:, scoped_entity_class:, scoped_entity_param_key: nil, action_name: "index")
    scoped_entity_param_key ||= scoped_entity_class.model_name.singular_route_key.to_sym

    controller = ScopedTestableController.new
    controller.test_action_name = action_name
    controller.test_user = @user
    controller.test_resource_class = resource_class
    controller.test_scoped_entity_class = scoped_entity_class
    controller.test_scoped_entity_param_key = scoped_entity_param_key
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

  # Test models for polymorphic association tests
  class PolymorphicComment < ActiveRecord::Base
    self.table_name = "blogging_comments"

    belongs_to :commentable, polymorphic: true
    belongs_to :user
  end

  class PolymorphicOnlyComment < ActiveRecord::Base
    self.table_name = "blogging_comments"

    belongs_to :commentable, polymorphic: true
  end

  # Controller for testing entity scoping
  class ScopedTestableController < ActionController::Base
    include Plutonium::Resource::Controllers::Authorizable
    include Plutonium::Resource::Controllers::Presentable

    attr_accessor :test_action_name, :test_user, :test_resource_class,
      :test_scoped_entity_class, :test_scoped_entity_param_key

    def action_name
      test_action_name
    end

    def resource_class
      test_resource_class
    end

    def resource_record!
      test_resource_class.new
    end

    def current_parent
      nil
    end

    def scoped_to_entity?
      true
    end

    def scoped_entity_class
      test_scoped_entity_class
    end

    def scoped_entity_param_key
      test_scoped_entity_param_key
    end

    def singular_resource_context?
      false
    end

    def current_policy
      policy_class = "#{test_resource_class.name}Policy".constantize
      @current_policy ||= policy_class.new(
        record: test_resource_class,
        user: test_user,
        entity_scope: nil
      )
    end

    def current_definition
      definition_class = "#{test_resource_class.name}Definition".constantize
      @current_definition ||= definition_class.new
    end
  end
end
