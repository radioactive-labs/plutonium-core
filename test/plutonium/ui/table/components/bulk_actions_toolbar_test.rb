# frozen_string_literal: true

require "test_helper"
require "plutonium/ui/table/components/bulk_actions_toolbar"

class Plutonium::UI::Table::Components::BulkActionsToolbarTest < Minitest::Test
  # ==================== Default hidden state ====================

  def test_toolbar_is_hidden_by_default
    html = build_toolbar(bulk_actions: []).call
    assert_match(/class="[^"]*hidden[^"]*"/, html)
  end

  def test_toolbar_has_bulk_actions_target
    html = build_toolbar(bulk_actions: []).call
    assert_match(/data-bulk-actions-target="toolbar"/, html)
  end

  # ==================== Tinted background ====================

  def test_toolbar_has_primary_tinted_background_light
    html = build_toolbar(bulk_actions: []).call
    assert_includes html, "bg-primary-50"
  end

  def test_toolbar_has_primary_tinted_background_dark
    html = build_toolbar(bulk_actions: []).call
    assert_includes html, "dark:bg-primary-950/30"
  end

  # ==================== Selected count ====================

  def test_renders_selected_count_target
    html = build_toolbar(bulk_actions: []).call
    assert_match(/data-bulk-actions-target="selectedCount"/, html)
  end

  def test_selected_count_initial_value_is_zero
    html = build_toolbar(bulk_actions: []).call
    assert_match(/data-bulk-actions-target="selectedCount"[^>]*>\s*0\s*</, html)
  end

  def test_renders_selected_text
    html = build_toolbar(bulk_actions: []).call
    assert_includes html, "selected"
  end

  # ==================== Clear selection button ====================

  def test_renders_clear_selection_button
    html = build_toolbar(bulk_actions: []).call
    assert_includes html, "Clear selection"
  end

  def test_clear_selection_button_bound_to_correct_action
    html = build_toolbar(bulk_actions: []).call
    assert_match(/data-action="click-&gt;bulk-actions#clearSelection"|data-action="click->bulk-actions#clearSelection"/, html)
  end

  def test_clear_selection_button_is_type_button
    html = build_toolbar(bulk_actions: []).call
    # Find the button with clear selection text — verify it has type="button"
    assert_match(/type="button"[^>]*>.*?Clear selection|Clear selection.*?type="button"/m, html)
  end

  # ==================== Primary text colors ====================

  def test_selected_count_has_primary_700_text
    html = build_toolbar(bulk_actions: []).call
    assert_includes html, "text-primary-700"
  end

  def test_clear_button_has_primary_700_text
    html = build_toolbar(bulk_actions: []).call
    assert_match(/text-primary-700[^"]*"[^>]*>.*?Clear selection|Clear selection.*?text-primary-700/m, html)
  end

  private

  def build_toolbar(bulk_actions:)
    component = Plutonium::UI::Table::Components::BulkActionsToolbar.allocate
    component.instance_variable_set(:@_context, {})
    component.instance_variable_set(:@bulk_actions, bulk_actions)
    component
  end
end
