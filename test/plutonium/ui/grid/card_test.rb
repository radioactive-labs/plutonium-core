# frozen_string_literal: true

require "test_helper"

# Unit tests for Grid::Card#slots override via card_fields parameter.
#
# The `slots` method normally reads from resource_definition.defined_grid_fields.
# When a `card_fields:` hash is passed at construction time it should take
# precedence over the definition's grid_fields, letting the kanban board
# declare its own slot layout without changing the resource definition.
class Plutonium::UI::Grid::CardSlotsTest < Minitest::Test
  def test_slots_uses_card_fields_when_provided
    definition = stub_definition(grid_fields: {header: :name})
    card = Plutonium::UI::Grid::Card.new(
      stub_record,
      resource_definition: definition,
      card_fields: {header: :title, meta: [:status]}
    )

    assert_equal({header: :title, meta: [:status]}, card.send(:slots))
  end

  def test_slots_falls_back_to_definition_when_card_fields_nil
    definition = stub_definition(grid_fields: {header: :name})
    card = Plutonium::UI::Grid::Card.new(
      stub_record,
      resource_definition: definition,
      card_fields: nil
    )

    assert_equal({header: :name}, card.send(:slots))
  end

  def test_slots_falls_back_to_definition_when_card_fields_not_given
    definition = stub_definition(grid_fields: {header: :name})
    card = Plutonium::UI::Grid::Card.new(
      stub_record,
      resource_definition: definition
    )

    assert_equal({header: :name}, card.send(:slots))
  end

  def test_card_fields_empty_hash_overrides_definition
    # An explicitly passed empty hash means "render no slots",
    # distinct from nil which means "use the definition".
    definition = stub_definition(grid_fields: {header: :name})
    card = Plutonium::UI::Grid::Card.new(
      stub_record,
      resource_definition: definition,
      card_fields: {}
    )

    assert_equal({}, card.send(:slots))
  end

  private

  def stub_definition(grid_fields:)
    d = Object.new
    d.define_singleton_method(:defined_grid_fields) { grid_fields }
    d
  end

  def stub_record
    Struct.new(:id).new(1)
  end
end
