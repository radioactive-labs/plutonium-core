# frozen_string_literal: true

require "test_helper"

class DefinitionActionsTest < Minitest::Test
  # Test action declarations as documented

  def test_default_crud_actions_exist
    definition_class = Class.new(Plutonium::Resource::Definition)

    actions = definition_class.defined_actions

    assert actions.key?(:new), "Expected :new action"
    assert actions.key?(:show), "Expected :show action"
    assert actions.key?(:edit), "Expected :edit action"
    assert actions.key?(:destroy), "Expected :destroy action"
  end

  def test_default_actions_have_correct_options
    definition_class = Class.new(Plutonium::Resource::Definition)
    actions = definition_class.defined_actions

    # :new action
    assert actions[:new].resource_action?
    assert_equal "primary", actions[:new].category.to_s

    # :show action
    assert actions[:show].collection_record_action?

    # :edit action
    assert actions[:edit].record_action?
    assert actions[:edit].collection_record_action?

    # :destroy action
    assert actions[:destroy].record_action?
    assert_equal "danger", actions[:destroy].category.to_s
    assert_equal "Are you sure?", actions[:destroy].confirmation
  end

  def test_simple_action_declaration
    definition_class = Class.new(Plutonium::Resource::Definition) do
      action :export,
        label: "Export Data",
        route_options: {action: :export},
        icon: Phlex::TablerIcons::Download,
        resource_action: true
    end

    actions = definition_class.defined_actions

    assert actions.key?(:export)
    assert_equal "Export Data", actions[:export].label
    assert actions[:export].resource_action?
  end

  def test_interactive_action_with_interaction
    # Create a test interaction
    test_interaction = Class.new(Plutonium::Resource::Interaction) do
      presents label: "Test Action", icon: Phlex::TablerIcons::Star
      attribute :resource
    end

    definition_class = Class.new(Plutonium::Resource::Definition) do
      action :test_action, interaction: test_interaction
    end

    actions = definition_class.defined_actions

    assert actions.key?(:test_action)
    assert actions[:test_action].is_a?(Plutonium::Action::Interactive)
  end

  def test_action_with_confirmation
    definition_class = Class.new(Plutonium::Resource::Definition) do
      action :archive,
        route_options: {action: :archive},
        confirmation: "Are you sure you want to archive?",
        record_action: true
    end

    actions = definition_class.defined_actions

    assert_equal "Are you sure you want to archive?", actions[:archive].confirmation
  end

  def test_action_categories
    definition_class = Class.new(Plutonium::Resource::Definition) do
      action :primary_action, route_options: {}, category: :primary, record_action: true
      action :secondary_action, route_options: {}, category: :secondary, record_action: true
      action :danger_action, route_options: {}, category: :danger, record_action: true
    end

    actions = definition_class.defined_actions

    assert_equal "primary", actions[:primary_action].category.to_s
    assert_equal "secondary", actions[:secondary_action].category.to_s
    assert_equal "danger", actions[:danger_action].category.to_s
  end

  def test_action_positioning
    definition_class = Class.new(Plutonium::Resource::Definition) do
      action :first, route_options: {}, position: 1, record_action: true
      action :last, route_options: {}, position: 1000, record_action: true
      action :middle, route_options: {}, position: 50, record_action: true
    end

    # Actions should be sorted by position
    instance = definition_class.new
    action_names = instance.defined_actions.keys

    first_index = action_names.index(:first)
    middle_index = action_names.index(:middle)
    last_index = action_names.index(:last)

    assert first_index < middle_index
    assert middle_index < last_index
  end

  def test_action_visibility_flags
    definition_class = Class.new(Plutonium::Resource::Definition) do
      action :resource_only,
        route_options: {},
        resource_action: true,
        record_action: false,
        collection_record_action: false

      action :record_only,
        route_options: {},
        resource_action: false,
        record_action: true,
        collection_record_action: false

      action :collection_only,
        route_options: {},
        resource_action: false,
        record_action: false,
        collection_record_action: true
    end

    actions = definition_class.defined_actions

    assert actions[:resource_only].resource_action?
    refute actions[:resource_only].record_action?
    refute actions[:resource_only].collection_record_action?

    refute actions[:record_only].resource_action?
    assert actions[:record_only].record_action?
    refute actions[:record_only].collection_record_action?

    refute actions[:collection_only].resource_action?
    refute actions[:collection_only].record_action?
    assert actions[:collection_only].collection_record_action?
  end

  def test_action_inheritance
    parent_class = Class.new(Plutonium::Resource::Definition) do
      action :parent_action, route_options: {}, record_action: true
    end

    child_class = Class.new(parent_class) do
      action :child_action, route_options: {}, record_action: true
    end

    child_instance = child_class.new
    actions = child_instance.defined_actions

    assert actions.key?(:parent_action)
    assert actions.key?(:child_action)
    # Should also have default CRUD actions
    assert actions.key?(:new)
    assert actions.key?(:show)
  end

  def test_blogging_post_definition_actions
    actions = Blogging::PostDefinition.defined_actions

    # Custom actions
    assert actions.key?(:publish), "Expected :publish action"
    assert actions.key?(:schedule), "Expected :schedule action"

    # Default CRUD actions
    assert actions.key?(:new)
    assert actions.key?(:show)
    assert actions.key?(:edit)
    assert actions.key?(:destroy)

    # Verify interactions are linked
    assert actions[:publish].is_a?(Plutonium::Action::Interactive)
    assert actions[:schedule].is_a?(Plutonium::Action::Interactive)
  end

  def test_instance_level_action_customization
    definition_class = Class.new(Plutonium::Resource::Definition) do
      def customize_actions
        action :dynamic_action, route_options: {}, record_action: true
      end
    end

    instance = definition_class.new
    actions = instance.defined_actions

    assert actions.key?(:dynamic_action)
  end
end
