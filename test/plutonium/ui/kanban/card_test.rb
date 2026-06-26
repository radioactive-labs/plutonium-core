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

  private

  def build_card(record:, column_key:)
    Plutonium::UI::Kanban::Card.new(
      record,
      column_key: column_key,
      resource_definition: nil,
      resource_fields: []
    )
  end

  def stub_record(id)
    Struct.new(:id).new(id)
  end
end
