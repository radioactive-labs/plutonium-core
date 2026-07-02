# frozen_string_literal: true

require "test_helper"
require "plutonium/kanban"

module Plutonium
  module Kanban
    class DslTest < Minitest::Test
      # ------------------------------------------------------------------ #
      # DSL.build returns a Board                                            #
      # ------------------------------------------------------------------ #

      def test_build_with_no_block_returns_board
        board = DSL.build
        assert_instance_of Board, board
      end

      def test_build_with_block_returns_board
        board = DSL.build { column :todo }
        assert_instance_of Board, board
      end

      # ------------------------------------------------------------------ #
      # Columns — declaration order, basic attributes                        #
      # ------------------------------------------------------------------ #

      def test_columns_keep_declaration_order
        board = DSL.build do
          column :todo
          column :in_progress
          column :done
        end
        assert_equal %i[todo in_progress done], board.columns.map(&:key)
      end

      def test_column_key_is_a_symbol
        board = DSL.build { column :todo }
        assert_equal :todo, board.columns.first.key
      end

      def test_column_label_defaults_to_titleized_key
        board = DSL.build { column :in_progress }
        assert_equal "In Progress", board.columns.first.label
      end

      def test_column_label_can_be_overridden
        board = DSL.build { column :todo, label: "To Do" }
        assert_equal "To Do", board.columns.first.label
      end

      def test_column_color_is_nil_by_default
        board = DSL.build { column :todo }
        assert_nil board.columns.first.color
      end

      def test_column_color_can_be_set
        board = DSL.build { column :todo, color: :blue }
        assert_equal :blue, board.columns.first.color
      end

      def test_column_wip_is_nil_by_default
        board = DSL.build { column :todo }
        assert_nil board.columns.first.wip
      end

      def test_column_wip_can_be_set
        board = DSL.build { column :todo, wip: 5 }
        assert_equal 5, board.columns.first.wip
      end

      # ------------------------------------------------------------------ #
      # scope / on_drop — Proc or Symbol stored verbatim                     #
      # ------------------------------------------------------------------ #

      def test_scope_proc_stored_verbatim
        my_scope = ->(r) { r.where(status: :todo) }
        board = DSL.build { column :todo, scope: my_scope }
        assert_same my_scope, board.columns.first.scope
      end

      def test_scope_symbol_stored_verbatim
        board = DSL.build { column :todo, scope: :active }
        assert_equal :active, board.columns.first.scope
      end

      def test_on_drop_proc_stored_verbatim
        my_drop = ->(record, col) { record.update!(status: col) }
        board = DSL.build { column :todo, on_drop: my_drop }
        assert_same my_drop, board.columns.first.on_drop
      end

      def test_on_drop_symbol_stored_verbatim
        board = DSL.build { column :todo, on_drop: :handle_drop }
        assert_equal :handle_drop, board.columns.first.on_drop
      end

      # ------------------------------------------------------------------ #
      # Role presets                                                          #
      # ------------------------------------------------------------------ #

      def test_role_backlog_sets_add_true
        board = DSL.build { column :backlog, role: :backlog }
        col = board.columns.first
        assert col.add?, "expected add? to be true for :backlog role"
      end

      def test_role_done_sets_color_green
        board = DSL.build { column :done, role: :done }
        col = board.columns.first
        assert_equal :green, col.color
      end

      def test_role_done_sets_collapsed_true
        board = DSL.build { column :done, role: :done }
        col = board.columns.first
        assert col.collapsed?, "expected collapsed? to be true for :done role"
      end

      def test_role_lost_sets_color_red
        board = DSL.build { column :lost, role: :lost }
        assert_equal :red, board.columns.first.color
      end

      def test_role_lost_sets_collapsed_true
        board = DSL.build { column :lost, role: :lost }
        assert board.columns.first.collapsed?, "expected collapsed? to be true for :lost role"
      end

      def test_explicit_color_overrides_role_preset
        board = DSL.build { column :done, role: :done, color: :purple }
        assert_equal :purple, board.columns.first.color
      end

      def test_explicit_collapsed_overrides_role_preset
        board = DSL.build { column :done, role: :done, collapsed: false }
        refute board.columns.first.collapsed?
      end

      def test_explicit_add_overrides_role_preset
        board = DSL.build { column :backlog, role: :backlog, add: false }
        refute board.columns.first.add?
      end

      def test_unknown_role_raises_argument_error
        error = assert_raises(ArgumentError) do
          DSL.build { column :weird, role: :bogus }
        end
        assert_match(/Unknown column role/, error.message)
      end

      # ------------------------------------------------------------------ #
      # Column-scoped actions                                                 #
      # ------------------------------------------------------------------ #

      def test_column_action_is_compiled
        board = DSL.build do
          column :todo do
            action :archive, interaction: :ArchiveTask
          end
        end
        col = board.columns.first
        assert_equal 1, col.actions.size
        assert_equal :archive, col.actions.first.key
      end

      def test_column_action_stores_interaction
        board = DSL.build do
          column :todo do
            action :archive, interaction: :ArchiveTask
          end
        end
        assert_equal :ArchiveTask, board.columns.first.actions.first.interaction
      end

      def test_column_action_defaults_on_to_all
        board = DSL.build do
          column :todo do
            action :archive, interaction: :ArchiveTask
          end
        end
        assert_equal :all, board.columns.first.actions.first.on
      end

      def test_column_action_custom_on
        board = DSL.build do
          column :todo do
            action :archive, interaction: :ArchiveTask, on: :selected
          end
        end
        assert_equal :selected, board.columns.first.actions.first.on
      end

      def test_column_action_optional_label
        board = DSL.build do
          column :todo do
            action :archive, interaction: :ArchiveTask, label: "Archive it"
          end
        end
        assert_equal "Archive it", board.columns.first.actions.first.label
      end

      def test_column_action_optional_icon
        board = DSL.build do
          column :todo do
            action :archive, interaction: :ArchiveTask, icon: :trash
          end
        end
        assert_equal :trash, board.columns.first.actions.first.icon
      end

      def test_column_action_optional_confirmation
        board = DSL.build do
          column :todo do
            action :archive, interaction: :ArchiveTask, confirmation: "Are you sure?"
          end
        end
        assert_equal "Are you sure?", board.columns.first.actions.first.confirmation
      end

      def test_multiple_actions_on_one_column
        board = DSL.build do
          column :todo do
            action :archive, interaction: :ArchiveTask
            action :delete, interaction: :DeleteTask
          end
        end
        assert_equal %i[archive delete], board.columns.first.actions.map(&:key)
      end

      # ------------------------------------------------------------------ #
      # Column#accepts?                                                       #
      # ------------------------------------------------------------------ #

      def test_accepts_defaults_to_true
        board = DSL.build { column :todo }
        assert board.columns.first.accepts?(:other)
      end

      def test_accepts_true_allows_any_key
        board = DSL.build { column :todo, accepts: true }
        assert board.columns.first.accepts?(:anything)
      end

      def test_accepts_false_rejects_any_key
        board = DSL.build { column :todo, accepts: false }
        refute board.columns.first.accepts?(:anything)
      end

      def test_accepts_array_includes
        board = DSL.build { column :todo, accepts: [:in_progress, :backlog] }
        assert board.columns.first.accepts?(:in_progress)
        refute board.columns.first.accepts?(:done)
      end

      def test_accepts_proc_permits_at_column_level
        col = Column.new(:todo, accepts: ->(card) { true })
        # Proc/predicate is permitted at the column level; the per-card
        # predicate is evaluated later by the move handler.
        assert_equal true, col.accepts?(:any)
      end

      # ------------------------------------------------------------------ #
      # Column#accepts_record? — per-card Proc evaluation                   #
      # ------------------------------------------------------------------ #

      def test_accepts_record_proc_returns_true_when_proc_permits
        record = Struct.new(:eligible).new(true)
        col = Column.new(:todo, accepts: ->(card) { card.eligible })

        assert col.accepts_record?(record, :other)
      end

      def test_accepts_record_proc_returns_false_when_proc_denies
        record = Struct.new(:eligible).new(false)
        col = Column.new(:todo, accepts: ->(card) { card.eligible })

        refute col.accepts_record?(record, :other)
      end

      def test_accepts_record_true_allows_any_record
        col = Column.new(:todo, accepts: true)

        assert col.accepts_record?(Object.new, :anything)
      end

      def test_accepts_record_false_denies_any_record
        col = Column.new(:todo, accepts: false)

        refute col.accepts_record?(Object.new, :anything)
      end

      def test_accepts_record_array_includes_source_key
        col = Column.new(:todo, accepts: [:in_progress, :backlog])

        assert col.accepts_record?(Object.new, :in_progress)
      end

      def test_accepts_record_array_excludes_absent_source_key
        col = Column.new(:todo, accepts: [:in_progress, :backlog])

        refute col.accepts_record?(Object.new, :done)
      end

      def test_accepts_record_ignores_record_for_array_case
        # record is irrelevant when accepts: is an Array; only source_key matters.
        col = Column.new(:todo, accepts: [:doing])
        any_record = Object.new

        assert col.accepts_record?(any_record, :doing)
        refute col.accepts_record?(any_record, :todo)
      end

      # ------------------------------------------------------------------ #
      # Board-level options                                                   #
      # ------------------------------------------------------------------ #

      def test_per_column_default_nil
        board = DSL.build {}
        assert_nil board.per_column
      end

      def test_per_column_set
        board = DSL.build { per_column 10 }
        assert_equal 10, board.per_column
      end

      def test_realtime_defaults_false
        board = DSL.build {}
        refute board.realtime?
      end

      def test_realtime_can_be_set_true
        board = DSL.build { realtime true }
        assert board.realtime?
      end

      def test_card_fields_default_nil
        board = DSL.build {}
        assert_nil board.card_fields
      end

      def test_card_fields_stored
        board = DSL.build { card_fields title: :name, body: :description }
        assert_equal({title: :name, body: :description}, board.card_fields)
      end

      def test_lazy_defaults_true
        board = DSL.build {}
        assert board.lazy?
      end

      def test_lazy_can_be_set_false
        board = DSL.build { lazy false }
        refute board.lazy?
      end

      # ------------------------------------------------------------------ #
      # show_in — where a card click opens the show page                     #
      # ------------------------------------------------------------------ #

      def test_show_in_defaults_to_nil_inherit
        board = DSL.build {}
        assert_nil board.show_in, "an unset board show_in should inherit the definition"
      end

      def test_show_in_can_be_set_to_modal
        board = DSL.build { show_in :modal }
        assert_equal :modal, board.show_in
      end

      def test_show_in_can_be_set_to_page
        board = DSL.build { show_in :page }
        assert_equal :page, board.show_in
      end

      def test_show_in_rejects_unknown_mode
        error = assert_raises(ArgumentError) { DSL.build { show_in :sidebar } }
        assert_match(/show_in must be one of/, error.message)
      end

      # show_in_for(definition): board value wins; otherwise inherit the definition.
      def test_show_in_for_inherits_definition_when_unset
        board = DSL.build {}
        definition = Struct.new(:show_in).new(:modal)
        assert_equal :modal, board.show_in_for(definition)
      end

      def test_show_in_for_board_overrides_definition
        board = DSL.build { show_in :page }
        definition = Struct.new(:show_in).new(:modal)
        assert_equal :page, board.show_in_for(definition)
      end

      # ------------------------------------------------------------------ #
      # Immutability — columns are deep-frozen                                #
      # ------------------------------------------------------------------ #

      def test_columns_collection_is_frozen
        board = DSL.build { column :todo }
        assert board.columns.frozen?
      end

      def test_pushing_to_columns_raises
        board = DSL.build { column :todo }
        assert_raises(FrozenError) { board.columns << Object.new }
      end

      def test_each_column_is_frozen
        board = DSL.build { column :todo }
        assert board.columns.first.frozen?
      end

      def test_card_fields_is_frozen_when_present
        board = DSL.build { card_fields title: :name }
        assert board.card_fields.frozen?
      end

      # ------------------------------------------------------------------ #
      # Dynamic columns block                                                 #
      # ------------------------------------------------------------------ #

      def test_dynamic_columns_block_stored
        blk = -> { [] }
        board = DSL.build { columns(&blk) }
        assert_equal blk, board.columns_block
      end

      def test_dynamic_true_when_columns_block_set
        board = DSL.build { columns { [] } }
        assert board.dynamic?
      end

      def test_dynamic_false_without_columns_block
        board = DSL.build { column :todo }
        refute board.dynamic?
      end

      # ------------------------------------------------------------------ #
      # position_on — wired to Positioning::Config factories                 #
      # ------------------------------------------------------------------ #

      def test_default_position_config_is_config_default
        board = DSL.build {}
        assert_equal :position, board.position_config.attribute
        refute board.position_config.disabled?
      end

      def test_position_on_attribute_uses_config_attribute_factory
        board = DSL.build { position_on :rank }
        assert_equal :rank, board.position_config.attribute
        refute board.position_config.disabled?
      end

      def test_position_on_false_disables_positioning
        board = DSL.build { position_on false }
        assert board.position_config.disabled?
      end

      def test_position_on_with_block_retains_block
        received_move = nil
        capture = ->(move) { received_move = move }
        board = DSL.build do
          position_on(:rank, &capture)
        end

        assert_equal :rank, board.position_config.attribute
        refute board.position_config.disabled?

        # Drive the stored config to prove the block was retained (Mode B).
        record = Object.new
        board.position_config.reposition!(
          record:, column: :c, prev_record: nil, next_record: nil, index: 0
        )
        assert_instance_of Positioning::Move, received_move
        assert_same record, received_move.record
        assert_equal :c, received_move.column
      end

      # ------------------------------------------------------------------ #
      # Behaviour flags                                                       #
      # ------------------------------------------------------------------ #

      def test_column_collapsed_defaults_false
        board = DSL.build { column :todo }
        refute board.columns.first.collapsed?
      end

      def test_column_add_defaults_false
        board = DSL.build { column :todo }
        refute board.columns.first.add?
      end

      def test_column_locked_defaults_false
        board = DSL.build { column :todo }
        refute board.columns.first.locked?
      end

      def test_column_locked_can_be_set
        board = DSL.build { column :todo, locked: true }
        assert board.columns.first.locked?
      end
    end
  end
end
