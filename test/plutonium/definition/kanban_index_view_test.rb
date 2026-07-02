# frozen_string_literal: true

require "test_helper"

class Plutonium::Definition::KanbanIndexViewTest < Minitest::Test
  # A real record interaction (has `attribute :resource`) with a conventional
  # "…Interaction" name so it registers as an interactive record action keyed
  # `:mark_lost` (see Kanban::Column#drop_interaction_key).
  class MarkLostInteraction < Plutonium::Resource::Interaction
    attribute :resource
    attribute :reason, :string

    input :reason

    validates :reason, presence: true

    private

    def execute
      resource.update!(status: "lost")
      succeed(resource)
    end
  end

  # A non-kanban record interaction, to prove kanban_drop? defaults to false.
  class ArchiveInteraction < Plutonium::Resource::Interaction
    attribute :resource

    private

    def execute
      succeed(resource)
    end
  end

  def def_class(&blk)
    Class.new(Plutonium::Resource::Definition) do
      class_eval(&blk) if blk
    end
  end

  def test_declaring_kanban_enables_the_kanban_view_alongside_table
    klass = def_class { kanban {} }
    assert_includes klass.defined_index_views, :kanban
    assert_includes klass.defined_index_views, :table
  end

  def test_kanban_stores_the_builder_block
    klass = def_class { kanban {} }
    assert_kind_of Proc, klass.defined_kanban_block
  end

  def test_kanban_is_a_known_view
    assert_includes Plutonium::Definition::IndexViews::KNOWN_VIEWS, :kanban
  end

  def test_calling_kanban_twice_does_not_duplicate_kanban_in_index_views
    klass = def_class do
      kanban {}
      kanban {}
    end
    assert_equal 1, klass.defined_index_views.count(:kanban)
  end

  # ------------------------------------------------------------------ #
  # drop_interaction auto-registration                                   #
  # ------------------------------------------------------------------ #

  def drop_definition
    interaction = MarkLostInteraction
    def_class do
      kanban do
        column :lost, scope: -> { all }, on_drop: ->(r) { r.status = "lost" },
          drop_interaction: interaction
      end
    end.new
  end

  def test_static_column_drop_interaction_registers_a_record_action
    action = drop_definition.defined_actions[:mark_lost]
    assert_kind_of Plutonium::Action::Interactive, action
    assert action.record_action?, "drop interaction should be a record action"
    assert_equal MarkLostInteraction, action.interaction
  end

  def test_registered_drop_action_is_flagged_kanban_drop
    assert drop_definition.defined_actions[:mark_lost].kanban_drop?
  end

  def test_non_kanban_record_action_is_not_kanban_drop
    definition = def_class { action(:archive, interaction: ArchiveInteraction) }.new
    refute definition.defined_actions[:archive].kanban_drop?
  end

  # Mirrors the filter used by the show/row/grid toolbars: displayable record
  # actions are `record_action? && !kanban_drop?`. The drop action must be
  # excluded (it is reachable only by dropping a card).
  def test_kanban_drop_action_excluded_from_displayable_record_actions
    definition = drop_definition
    displayable = definition.defined_actions.values.select { |a| a.record_action? && !a.kanban_drop? }
    refute_includes displayable.map(&:name), :mark_lost
    # And it IS present as a registered (but hidden) action.
    assert_includes definition.defined_actions.keys, :mark_lost
  end

  # Dynamic boards (`columns do … end`) expose no static columns at load time,
  # so nothing is introspectable and no drop action is registered — no crash.
  def test_dynamic_board_registers_no_drop_action
    definition = def_class do
      kanban do
        columns { [] }
      end
    end.new
    assert_empty definition.defined_actions.keys.grep(/mark_lost|drop/)
  end
end
