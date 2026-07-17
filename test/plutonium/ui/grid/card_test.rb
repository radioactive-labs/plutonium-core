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

# Unit tests for Grid::Card#footer_field.
#
# The footer slot falls back to :created_at when undeclared, so — unlike every
# other slot — omitting it does NOT remove the footer. `footer: false` is the
# opt-out for cards that want no footer line at all.
class Plutonium::UI::Grid::CardFooterFieldTest < Minitest::Test
  def test_footer_falls_back_to_created_at_when_slot_undeclared
    assert_equal :created_at, footer_field_for({header: :title})
  end

  def test_footer_uses_the_declared_slot
    assert_equal :updated_at, footer_field_for({header: :title, footer: :updated_at})
  end

  def test_footer_false_disables_the_footer
    assert_nil footer_field_for({header: :title, footer: false})
  end

  # nil keeps meaning "undeclared" (→ fall back); only false opts out. Guards the
  # back-compat boundary: `footer: some_nil_var` must not silently drop the footer.
  def test_footer_nil_still_falls_back
    assert_equal :created_at, footer_field_for({header: :title, footer: nil})
  end

  def test_footer_is_absent_when_the_record_has_no_created_at
    assert_nil footer_field_for({header: :title}, record: Struct.new(:id).new(1))
  end

  private

  def footer_field_for(card_fields, record: Struct.new(:id, :created_at).new(1, Time.now))
    definition = Object.new
    definition.define_singleton_method(:defined_grid_fields) { {} }
    Plutonium::UI::Grid::Card.new(
      record, resource_definition: definition, card_fields: card_fields
    ).send(:footer_field)
  end
end
