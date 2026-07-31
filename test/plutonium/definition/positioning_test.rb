# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Definition
    class PositioningTest < Minitest::Test
      # Anonymous definitions have no name to infer a model from, so stub
      # model_class the way a hand-written definition would override it.
      def build_definition(model, &block)
        Class.new(Plutonium::Resource::Definition) do
          define_singleton_method(:model_class) { model }
          class_eval(&block) if block
        end
      end

      # ------------------------------------------------------------------ #
      # The four DSL forms                                                   #
      # ------------------------------------------------------------------ #

      def test_bare_position_on_defaults_to_the_position_attribute
        definition = build_definition(::Task) { position_on }
        config = definition.new.defined_position_config

        assert_equal :position, config.attribute
        refute config.disabled?
      end

      def test_custom_attribute
        definition = build_definition(::Task) { position_on :sort_order }
        assert_equal :sort_order, definition.new.defined_position_config.attribute
      end

      def test_block_form_retains_the_block
        received = nil
        capture = ->(move) { received = move }
        definition = build_definition(::Comment) { position_on(:rank, &capture) }
        config = definition.new.defined_position_config

        assert_equal :rank, config.attribute
        refute config.disabled?

        record = Object.new
        config.reposition!(record:, prev_record: nil, next_record: nil, index: 0)
        assert_instance_of Plutonium::Positioning::Move, received
        assert_same record, received.record
      end

      def test_false_disables_ordering
        definition = build_definition(::Task) { position_on false }
        assert definition.new.defined_position_config.disabled?
      end

      def test_undeclared_definition_has_no_position_config
        assert_nil build_definition(::Task).new.defined_position_config
      end

      # ------------------------------------------------------------------ #
      # The sort / default_sort / action expansion                           #
      # ------------------------------------------------------------------ #

      def test_position_on_registers_the_sort_and_the_default_sort
        definition = build_definition(::Task) { position_on }

        assert_equal [:position, :asc], definition._default_sort
        assert_includes definition.defined_sorts.keys, :position
      end

      def test_position_on_registers_a_hidden_reposition_action
        definition = build_definition(::Task) { position_on }
        action = definition.defined_actions[:reposition]

        refute_nil action
        assert action.hidden?
      end

      def test_block_form_expands_the_same_way
        definition = build_definition(::Comment) { position_on(:rank) { |move| move } }

        assert_equal [:rank, :asc], definition._default_sort
        assert_includes definition.defined_sorts.keys, :rank
        assert definition.defined_actions[:reposition].hidden?
      end

      def test_disabled_registers_nothing
        definition = build_definition(::Task) { position_on false }

        assert_nil definition.defined_actions[:reposition]
        refute_includes definition.defined_sorts.keys, :position
        refute_equal [:position, :asc], definition._default_sort
      end

      def test_default_sort_can_be_overridden_after_position_on
        definition = build_definition(::Task) do
          position_on
          default_sort :title, :desc
        end

        assert_equal [:title, :desc], definition._default_sort
        # The sort itself stays permitted — otherwise there would be no way to
        # sort back into the drag-orderable state.
        assert_includes definition.defined_sorts.keys, :position
      end

      # ------------------------------------------------------------------ #
      # Mode A's boot-time model contract                                    #
      # ------------------------------------------------------------------ #

      # Mode A delegates to record.reposition!, which only exists on models that
      # include the concern. Failing at class-load time beats a 500 on first drag.
      def test_mode_a_requires_the_model_to_include_the_concern
        error = assert_raises(ArgumentError) do
          build_definition(::Comment) { position_on }
        end

        assert_match(/Plutonium::Positioning::Model/, error.message)
        assert_match(/Comment/, error.message)
      end

      # Mode B never calls reposition!, so the concern is irrelevant.
      def test_mode_b_does_not_require_the_concern
        definition = build_definition(::Comment) do
          position_on(:rank) { |move| move.record.insert_at(move.index + 1) }
        end

        assert_equal :rank, definition.new.defined_position_config.attribute
      end

      # Mode C never orders anything, so it has no model contract either.
      def test_mode_c_does_not_require_the_concern
        definition = build_definition(::Comment) { position_on false }
        assert definition.new.defined_position_config.disabled?
      end

      # ------------------------------------------------------------------ #
      # model_class inference (what Mode A's check reads)                    #
      # ------------------------------------------------------------------ #

      def test_model_class_is_inferred_from_the_definition_name
        assert_equal ::Task, ::TaskDefinition.model_class
      end

      # A definition namespaced under a portal/package the model is not in
      # drops leading segments until a constant resolves.
      def test_model_class_skips_namespaces_the_model_does_not_share
        assert_equal ::Blogging::Tutorial, ::AdminPortal::Blogging::TutorialDefinition.model_class
      end

      def test_model_class_raises_for_an_anonymous_definition
        assert_raises(NameError) { Class.new(Plutonium::Resource::Definition).model_class }
      end

      # ------------------------------------------------------------------ #
      # Kanban board inheritance                                             #
      # ------------------------------------------------------------------ #

      def test_board_inherits_the_definitions_position_on
        definition = build_definition(::Task) do
          position_on :sort_order
          kanban { column :todo }
        end

        config = definition.defined_kanban_board.position_config_for(definition.new)
        assert_equal :sort_order, config.attribute
      end

      def test_a_board_block_overrides_the_definition
        definition = build_definition(::Task) do
          position_on :sort_order
          kanban do
            column :todo
            position_on :board_rank
          end
        end

        board = definition.defined_kanban_board
        assert_equal :board_rank, board.position_config_for(definition.new).attribute
      end

      def test_a_board_block_can_disable_what_the_definition_enabled
        definition = build_definition(::Task) do
          position_on
          kanban do
            column :todo
            position_on false
          end
        end

        board = definition.defined_kanban_board
        assert board.position_config_for(definition.new).disabled?
      end

      # A board on a definition with no position_on keeps the historic default.
      def test_board_falls_back_to_the_default_when_nothing_is_declared
        definition = build_definition(::Task) { kanban { column :todo } }
        config = definition.defined_kanban_board.position_config_for(definition.new)

        assert_equal :position, config.attribute
        refute config.disabled?
      end

      # The reason position_config_for resolves lazily instead of at build time:
      # `kanban` compiles the board eagerly during the class body, so a board
      # built BEFORE a later position_on line would silently miss it.
      def test_resolution_is_lazy_so_declaration_order_does_not_matter
        definition = build_definition(::Task) do
          kanban { column :todo }
          position_on :sort_order
        end

        config = definition.defined_kanban_board.position_config_for(definition.new)
        assert_equal :sort_order, config.attribute
      end
    end
  end
end
