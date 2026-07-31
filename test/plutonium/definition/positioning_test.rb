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
        definition = build_definition(positioned_model(:sort_order)) { position_on :sort_order }
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

      def test_default_sort_declared_above_position_on_survives
        definition = build_definition(::Task) do
          default_sort :title, :desc
          position_on
        end

        assert_equal [:title, :desc], definition._default_sort
        assert_includes definition.defined_sorts.keys, :position
      end

      # ------------------------------------------------------------------ #
      # Mode A's boot-time model contract                                    #
      # ------------------------------------------------------------------ #

      # An AR model on an existing table, so include?/positioning_column/
      # positioning_declared are all the real thing rather than a stub.
      def positioned_model(column = nil)
        Class.new(ActiveRecord::Base) do
          self.table_name = "tasks"
          include Plutonium::Positioning::Model

          positioned_on column if column
        end
      end

      # Mode A delegates to record.reposition!, which only exists on models that
      # include the concern. Failing at class-load time beats a 500 on first drag.
      def test_mode_a_requires_the_model_to_include_the_concern
        error = assert_raises(ArgumentError) do
          build_definition(::Comment) { position_on }
        end

        assert_match(/Plutonium::Positioning::Model/, error.message)
        assert_match(/Comment/, error.message)
      end

      # Including the concern without calling positioned_on skips the
      # before_create hook, so every row is created with a nil position.
      def test_mode_a_requires_the_model_to_declare_positioned_on
        model = positioned_model
        error = assert_raises(ArgumentError) do
          build_definition(model) { position_on }
        end

        assert_match(/declare `positioned_on`/, error.message)
      end

      # The model owns the column, so a bare position_on follows whatever it
      # declared instead of assuming :position.
      def test_bare_position_on_follows_the_models_column
        definition = build_definition(positioned_model(:sort_order)) { position_on }
        assert_equal :sort_order, definition.new.defined_position_config.attribute
      end

      # Both divergence directions order by one column while reposition! writes
      # another — the drag would silently do nothing.
      def test_an_attribute_that_contradicts_the_model_raises
        error = assert_raises(ArgumentError) do
          build_definition(::Task) { position_on :sort_order }
        end

        assert_match(/contradicts/, error.message)
        assert_match(/positioned_on :position/, error.message)
      end

      def test_an_attribute_that_contradicts_the_model_raises_the_other_way
        error = assert_raises(ArgumentError) do
          build_definition(positioned_model(:sort_order)) { position_on :position }
        end

        assert_match(/contradicts/, error.message)
      end

      def test_an_attribute_that_matches_the_model_is_accepted
        definition = build_definition(::Task) { position_on :position }
        assert_equal :position, definition.new.defined_position_config.attribute
      end

      # Mode B's block owns the write, so its attribute answers to nothing but
      # the ordering — no model contract to contradict.
      def test_mode_b_attribute_is_free_form
        definition = build_definition(::Task) { position_on(:whatever) { |move| move } }
        assert_equal :whatever, definition.new.defined_position_config.attribute
      end

      def test_mode_b_without_an_attribute_still_defaults_to_position
        definition = build_definition(::Comment) { position_on { |move| move } }
        assert_equal :position, definition.new.defined_position_config.attribute
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
      # drops leading segments until a model resolves.
      def test_model_class_skips_namespaces_the_model_does_not_share
        assert_equal ::Blogging::Tutorial, ::AdminPortal::Blogging::TutorialDefinition.model_class
      end

      def test_model_class_raises_for_an_anonymous_definition
        assert_raises(NameError) { Class.new(Plutonium::Resource::Definition).model_class }
      end

      # The search accepts only ActiveRecord models. Without that, the first
      # constant that merely resolves wins — and Ruby's const_get falls back to
      # Object, so a definition demodulizing to a stdlib name would silently
      # memoize it (::Set is a Class; ::Process is not even that).
      def test_model_class_skips_a_constant_that_is_not_a_model
        Object.const_set(:SetDefinition, Class.new(Plutonium::Resource::Definition))
        error = assert_raises(NameError) { ::SetDefinition.model_class }
        assert_match(/could not infer a model class/, error.message)
      ensure
        Object.send(:remove_const, :SetDefinition)
      end

      # `Foo::Definition` demodulizes to an empty base — without the guard,
      # split("::") drops the empty tail and the parent NAMESPACE is returned.
      def test_model_class_raises_for_a_definition_named_only_definition
        Object.const_set(:PositioningNamespaceStub, Module.new)
        ::PositioningNamespaceStub.const_set(:Definition, Class.new(Plutonium::Resource::Definition))

        error = assert_raises(NameError) { ::PositioningNamespaceStub::Definition.model_class }
        assert_match(/naming convention/, error.message)
      ensure
        Object.send(:remove_const, :PositioningNamespaceStub)
      end

      # The framework's own base class is exactly that shape, and memoization
      # would have cached the Plutonium::Resource MODULE for the process.
      def test_the_framework_base_definition_has_no_model_class
        assert_raises(NameError) { Plutonium::Resource::Definition.model_class }
      end

      # ------------------------------------------------------------------ #
      # Kanban board inheritance                                             #
      # ------------------------------------------------------------------ #

      def test_board_inherits_the_definitions_position_on
        definition = build_definition(positioned_model(:sort_order)) do
          position_on :sort_order
          kanban { column :todo }
        end

        config = definition.defined_kanban_board.position_config_for(definition.new)
        assert_equal :sort_order, config.attribute
      end

      def test_a_board_block_overrides_the_definition
        definition = build_definition(positioned_model(:sort_order)) do
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
        definition = build_definition(positioned_model(:sort_order)) do
          kanban { column :todo }
          position_on :sort_order
        end

        config = definition.defined_kanban_board.position_config_for(definition.new)
        assert_equal :sort_order, config.attribute
      end
    end
  end
end
