# frozen_string_literal: true

require "test_helper"

# Ensure the selection column components are loaded
require "plutonium/ui/table/components/selection_column"

class Plutonium::UI::Table::Components::SelectionColumnTest < Minitest::Test
  def test_value_key_defaults_to_model_primary_key
    component = build_component(
      model_class: ModelWithStandardPrimaryKey,
      options: {}
    )

    assert_equal :id, component.send(:value_key)
  end

  def test_value_key_defaults_to_custom_primary_key
    component = build_component(
      model_class: ModelWithUuidPrimaryKey,
      options: {}
    )

    assert_equal :uuid, component.send(:value_key)
  end

  def test_value_key_option_overrides_default
    component = build_component(
      model_class: ModelWithStandardPrimaryKey,
      options: {value_key: :custom_field}
    )

    assert_equal :custom_field, component.send(:value_key)
  end

  def test_bulk_actions_returns_empty_array_by_default
    component = build_component(
      model_class: ModelWithStandardPrimaryKey,
      options: {}
    )

    assert_equal [], component.send(:bulk_actions)
  end

  def test_bulk_actions_returns_provided_actions
    actions = [MockAction.new(:delete), MockAction.new(:archive)]
    component = build_component(
      model_class: ModelWithStandardPrimaryKey,
      options: {bulk_actions: actions}
    )

    assert_equal actions, component.send(:bulk_actions)
  end

  def test_compute_allowed_actions_returns_all_action_names_without_policy_resolver
    actions = [MockAction.new(:delete), MockAction.new(:archive)]
    component = build_component(
      model_class: ModelWithStandardPrimaryKey,
      options: {bulk_actions: actions}
    )

    result = component.send(:compute_allowed_actions, Object.new)
    assert_equal %w[delete archive], result
  end

  def test_compute_allowed_actions_filters_by_policy
    delete_action = MockAction.new(:delete)
    archive_action = MockAction.new(:archive)
    actions = [delete_action, archive_action]

    policy = MockPolicy.new(delete?: true, archive?: false)
    component = build_component(
      model_class: ModelWithStandardPrimaryKey,
      options: {
        bulk_actions: actions,
        policy_resolver: ->(_record) { policy }
      }
    )

    result = component.send(:compute_allowed_actions, Object.new)
    assert_equal %w[delete], result
  end

  def test_compute_allowed_actions_returns_empty_when_all_denied
    actions = [MockAction.new(:delete), MockAction.new(:archive)]
    policy = MockPolicy.new(delete?: false, archive?: false)
    component = build_component(
      model_class: ModelWithStandardPrimaryKey,
      options: {
        bulk_actions: actions,
        policy_resolver: ->(_record) { policy }
      }
    )

    result = component.send(:compute_allowed_actions, Object.new)
    assert_equal [], result
  end

  private

  def build_component(model_class:, options:)
    component = Plutonium::UI::Table::Components::SelectionColumn.allocate

    # Set instance variables
    component.instance_variable_set(:@key, :_selection)
    component.instance_variable_set(:@options, options)

    # Create a sample instance that responds to class
    sample_instance = model_class.new

    # Stub parent with sample
    parent = Object.new
    parent.define_singleton_method(:sample) { sample_instance }
    component.instance_variable_set(:@parent, parent)

    component
  end

  # Test model with standard integer primary key
  class ModelWithStandardPrimaryKey
    def self.primary_key
      "id"
    end
  end

  # Test model with UUID primary key
  class ModelWithUuidPrimaryKey
    def self.primary_key
      "uuid"
    end
  end

  # Mock action for testing
  class MockAction
    attr_reader :name

    def initialize(name)
      @name = name
    end
  end

  # Mock policy for testing
  class MockPolicy
    def initialize(**permissions)
      @permissions = permissions
    end

    def allowed_to?(action)
      @permissions.fetch(action, false)
    end
  end
end

class Plutonium::UI::Table::Components::SelectionDataCellTest < Minitest::Test
  def test_renders_checkbox_when_actions_available
    cell = Plutonium::UI::Table::Components::SelectionDataCell.new("123", %w[delete archive])

    html = cell.call

    assert_includes html, 'type="checkbox"'
    assert_includes html, 'value="123"'
    assert_includes html, 'data-allowed-actions="delete,archive"'
  end

  def test_renders_x_mark_when_no_actions_available
    cell = Plutonium::UI::Table::Components::SelectionDataCell.new("123", [])

    html = cell.call

    refute_includes html, 'type="checkbox"'
    assert_includes html, "No bulk actions available"
  end
end

class Plutonium::UI::Table::Components::SelectionHeaderCellTest < Minitest::Test
  def test_renders_select_all_checkbox
    cell = Plutonium::UI::Table::Components::SelectionHeaderCell.new

    html = cell.call

    assert_includes html, 'type="checkbox"'
    assert_includes html, 'data-bulk-actions-target="checkboxAll"'
    assert_includes html, 'data-action="bulk-actions#toggleAll"'
  end
end
