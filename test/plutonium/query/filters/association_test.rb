# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Query
    module Filters
      class AssociationTest < Minitest::Test
        class MockScope
          attr_reader :calls

          def initialize
            @calls = []
          end

          def where(*args, **kwargs)
            @calls << [:where, [], kwargs]
            self
          end
        end

        # Mock class for explicit class_name testing
        class MockCategory
          def self.all
            []
          end
        end

        # Mocks a resource_class whose association key does NOT match the target
        # class name (e.g. belongs_to :related_user, class_name: "User"). Only the
        # reflection knows the real class; key-inference would constantize the wrong
        # name and raise.
        class MockReflection
          def klass = MockCategory
        end

        class MockResourceWithReflection
          def self.reflect_on_association(_key) = MockReflection.new
        end

        # ==================== Initialization Tests ====================

        def test_initialization_with_explicit_class
          filter = Association.new(key: :category, class_name: MockCategory)

          assert_equal :category, filter.key
        end

        def test_initialization_with_multiple_true
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)

          assert_equal :category, filter.key
        end

        # ==================== Class Resolution Tests ====================

        def test_resolves_class_from_reflection_when_key_mismatches_class_name
          # No class_name given; key (:related_user) would constantize to a
          # nonexistent "RelatedUser". The reflection off resource_class is the
          # only thing that resolves it. Regression: the bridge must thread
          # resource_class through for this to work.
          filter = Association.new(key: :related_user, resource_class: MockResourceWithReflection)

          assert_equal MockCategory, filter.send(:association_class)
        end

        def test_explicit_class_name_takes_precedence_over_reflection
          filter = Association.new(
            key: :related_user,
            class_name: MockCategory,
            resource_class: MockResourceWithReflection
          )

          assert_equal MockCategory, filter.send(:association_class)
        end

        # ==================== Apply Tests - Single Value ====================

        def test_apply_with_single_value
          filter = Association.new(key: :category, class_name: MockCategory)
          scope = MockScope.new

          filter.apply(scope, value: "1")

          assert_equal [[:where, [], {category_id: ["1"]}]], scope.calls
        end

        def test_apply_with_integer_value
          filter = Association.new(key: :category, class_name: MockCategory)
          scope = MockScope.new

          filter.apply(scope, value: 42)

          assert_equal [[:where, [], {category_id: [42]}]], scope.calls
        end

        def test_apply_with_blank_value_returns_scope
          filter = Association.new(key: :category, class_name: MockCategory)
          scope = MockScope.new

          result = filter.apply(scope, value: "")

          assert_equal scope, result
          assert_empty scope.calls
        end

        def test_apply_with_nil_value_returns_scope
          filter = Association.new(key: :category, class_name: MockCategory)
          scope = MockScope.new

          result = filter.apply(scope, value: nil)

          assert_equal scope, result
          assert_empty scope.calls
        end

        # ==================== Apply Tests - Multiple Values ====================

        def test_apply_with_multiple_values
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)
          scope = MockScope.new

          filter.apply(scope, value: ["1", "2", "3"])

          assert_equal [[:where, [], {category_id: ["1", "2", "3"]}]], scope.calls
        end

        def test_apply_with_multiple_values_filters_blank
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)
          scope = MockScope.new

          filter.apply(scope, value: ["1", "", "3"])

          assert_equal [[:where, [], {category_id: ["1", "3"]}]], scope.calls
        end

        def test_apply_with_empty_array_returns_scope
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)
          scope = MockScope.new

          result = filter.apply(scope, value: [])

          assert_equal scope, result
          assert_empty scope.calls
        end

        def test_apply_with_all_blank_array_returns_scope
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)
          scope = MockScope.new

          result = filter.apply(scope, value: ["", ""])

          # All-blank array filters down to empty ids — skip the where
          # rather than emit `WHERE column IN ()` (invalid SQL).
          assert_equal scope, result
          assert_empty scope.calls
        end

        # ==================== Foreign Key Tests ====================

        def test_uses_correct_foreign_key
          filter = Association.new(key: :author, class_name: MockCategory)
          scope = MockScope.new

          filter.apply(scope, value: "5")

          assert_equal [[:where, [], {author_id: ["5"]}]], scope.calls
        end

        # ==================== Input Definition Tests ====================

        def test_customize_inputs_defines_value_input
          filter = Association.new(key: :category, class_name: MockCategory)

          assert filter.defined_inputs.key?(:value)
        end

        def test_customize_inputs_sets_resource_select_type
          filter = Association.new(key: :category, class_name: MockCategory)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal :resource_select, input_options[:as]
        end

        def test_customize_inputs_passes_association_class
          filter = Association.new(key: :category, class_name: MockCategory)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal MockCategory, input_options[:association_class]
        end

        def test_customize_inputs_sets_multiple_option
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)
          input_options = filter.defined_inputs[:value][:options]

          assert input_options[:multiple]
        end

        def test_customize_inputs_sets_include_blank_for_single_select
          filter = Association.new(key: :category, class_name: MockCategory, multiple: false)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal "All", input_options[:include_blank]
        end

        def test_customize_inputs_no_include_blank_for_multiple_select
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal false, input_options[:include_blank]
        end

        # ==================== Scope Forwarding Tests ====================
        # Regression: the `scope:` parameter was stored on @scope_proc but
        # never forwarded to the resource_select input, so the documented
        # feature silently did nothing. These prove the proc now reaches
        # the input that ResourceSelect consumes.

        def test_customize_inputs_forwards_scope_proc_to_input
          scope_proc = ->(s) { s.verified }
          filter = Association.new(key: :user, class_name: MockCategory, scope: scope_proc)
          input_options = filter.defined_inputs[:value][:options]

          assert_same scope_proc, input_options[:scope]
        end

        def test_customize_inputs_forwards_symbol_scope_to_input
          filter = Association.new(key: :user, class_name: MockCategory, scope: :verified)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal :verified, input_options[:scope]
        end

        def test_customize_inputs_scope_defaults_to_nil_when_omitted
          filter = Association.new(key: :user, class_name: MockCategory)
          input_options = filter.defined_inputs[:value][:options]

          assert_nil input_options[:scope]
        end

        # ==================== scoped_relation Dispatch Tests ====================
        # `humanize_value` (the active-filter pill label resolver) routes its
        # label lookups through a `scoped_relation` helper that mirrors the
        # arity-aware `apply_scope` shared by ResourceSelect#authorized_relation
        # and Typeahead#filter_association. The dispatch (Symbol / arity-0 Proc
        # / arity-1 Proc / nil) and the loud ArgumentError for unsupported types
        # must stay in lock-step with those two sites — any divergence re-opens
        # the leak this method closes. These tests verify the dispatch wiring
        # without requiring a database.

        # A spy that imitates the sufficient surface of an ActiveRecord relation
        # for scope dispatch: `.all`, chainable `.where`, named-scope capture
        # (via method_missing), and `#map` so `humanize_value` can iterate.
        class ScopeSpyRelation
          attr_reader :named_scope_calls, :where_clauses
          attr_accessor :records

          def initialize(records: [])
            @named_scope_calls = []
            @where_clauses = []
            @records = records
          end

          def all
            self
          end

          # ActiveRecord relations chain — `where` returns a relation. Returning
          # `self` keeps the spy observable across chained calls; the arguments
          # of every `where` accumulate in `where_clauses`.
          def where(*args, **kwargs)
            @where_clauses << {args: args, kwargs: kwargs}
            self
          end

          def map(&) = @records.map(&)

          # Captures any Symbol-named scope invocation (`relation.verified`),
          # returning `self` so further chaining also works.
          def method_missing(name, *args, **kwargs, &block)
            @named_scope_calls << name
            self
          end

          def respond_to_missing?(name, include_private = false)
            true
          end
        end

        class ScopeSpyClass
          def self.all
            ScopeSpyRelation.new
          end
        end

        def test_scoped_relation_returns_relation_unchanged_when_scope_is_nil
          filter = Association.new(key: :category, class_name: ScopeSpyClass, scope: nil)
          relation = filter.send(:scoped_relation)

          assert_kind_of ScopeSpyRelation, relation
          assert_empty relation.named_scope_calls
          assert_empty relation.where_clauses
        end

        def test_scoped_relation_dispatches_symbol_scope_via_public_send
          filter = Association.new(key: :category, class_name: ScopeSpyClass, scope: :verified)
          relation = filter.send(:scoped_relation)

          assert_includes relation.named_scope_calls, :verified
          assert_empty relation.where_clauses
        end

        def test_scoped_relation_dispatches_zero_arity_proc_via_instance_exec
          scope = -> { where(id: [1]) }
          filter = Association.new(key: :category, class_name: ScopeSpyClass, scope: scope)
          relation = filter.send(:scoped_relation)

          # The kanban form runs the proc in the relation's context, so its
          # `where` lands on the spy.
          assert relation.where_clauses.any? { |c| c[:kwargs] == {id: [1]} }
        end

        def test_scoped_relation_dispatches_one_arity_proc_passing_the_relation
          passed = nil
          scope = ->(r) do
            passed = r
            r.where(id: [2])
          end
          filter = Association.new(key: :category, class_name: ScopeSpyClass, scope: scope)
          relation = filter.send(:scoped_relation)

          refute_nil passed
          assert_kind_of ScopeSpyRelation, passed
          assert relation.where_clauses.any? { |c| c[:kwargs] == {id: [2]} }
        end

        def test_scoped_relation_raises_argument_error_for_unsupported_scope_type
          filter = Association.new(key: :category, class_name: ScopeSpyClass, scope: "active")

          assert_raises(ArgumentError) { filter.send(:scoped_relation) }
        end

        def test_humanize_value_falls_back_to_raw_value_when_scope_raises
          # `scoped_relation` raises ArgumentError for an unsupported scope
          # type; `humanize_value`'s broad rescue swallows it and returns the
          # raw id the caller supplied rather than the hidden record's label
          # (so an attacker who controls the URL only ever sees their own
          # input echoed back). This pins the safe-fallback behaviour so
          # future narrowing of the rescue can't silently regress to a leak.
          filter = Association.new(key: :category, class_name: ScopeSpyClass, scope: "active")

          assert_equal "42", filter.humanize_value("42")
        end
      end
    end
  end
end
