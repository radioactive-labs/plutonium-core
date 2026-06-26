# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Kanban::CardTest < Minitest::Test
  def test_draggable_attrs_present
    card = build_card(record: stub_record(42), column_key: :todo)
    card.define_singleton_method(:render_grid_card) { }

    html = card.call

    assert_match(/draggable="true"/, html)
    assert_match(/data-kanban-record-id="42"/, html)
    assert_match(/data-kanban-column-key="todo"/, html)
  end

  def test_column_key_is_stringified
    card = build_card(record: stub_record(7), column_key: :in_progress)
    card.define_singleton_method(:render_grid_card) { }

    html = card.call

    assert_match(/data-kanban-column-key="in_progress"/, html)
  end

  def test_render_grid_card_is_the_delegation_seam
    card = build_card(record: stub_record(1), column_key: :todo)
    called = false
    card.define_singleton_method(:render_grid_card) { called = true }

    card.call

    assert called, "view_template should delegate to render_grid_card"
  end

  # ─── card_fields threading ────────────────────────────────────────────────

  def test_card_fields_defaults_to_nil
    card = build_card(record: stub_record(1), column_key: :todo)

    assert_nil card.card_fields
  end

  def test_card_fields_stored_when_provided
    card_fields = {header: :title, meta: [:status]}
    card = build_card_with_fields(record: stub_record(1), column_key: :todo, card_fields: card_fields)

    assert_equal card_fields, card.card_fields
  end

  def test_render_grid_card_passes_card_fields_to_grid_card
    # Verifies that render_grid_card threads card_fields through to Grid::Card.
    # We stub `render` (the Phlex helper) to capture the constructed Grid::Card
    # instance without needing a live view context.
    card_fields = {header: :title, meta: [:status]}
    record = stub_record(1)
    card = build_card_with_fields(record: record, column_key: :todo, card_fields: card_fields)

    captured = nil
    card.define_singleton_method(:render) { |c| captured = c }
    card.send(:render_grid_card)

    assert_instance_of Plutonium::UI::Grid::Card, captured
    assert_equal card_fields, captured.instance_variable_get(:@card_fields)
  end

  private

  def build_card(record:, column_key:)
    Plutonium::UI::Kanban::Card.new(
      record,
      column_key: column_key,
      resource_definition: nil,
      resource_fields: []
    )
  end

  def build_card_with_fields(record:, column_key:, card_fields:)
    Plutonium::UI::Kanban::Card.new(
      record,
      column_key: column_key,
      resource_definition: nil,
      resource_fields: [],
      card_fields: card_fields
    )
  end

  def stub_record(id)
    Struct.new(:id).new(id)
  end
end
