# frozen_string_literal: true

require "test_helper"

# Regression: `Association#humanize_value` is the code path that renders the
# active-filter pill's value label from RAW params (`QueryObject` is built from
# `raw_resource_query_params`, see `Plutonium::Resource::QueryObject#active_filter_descriptions`).
# Commit 4bbe82b4 wired the `scope:` option through the dropdown
# (`ResourceSelect#authorized_relation`), the typeahead (`Typeahead#filter_association`),
# and the submission validator (`ResourceSelect#normalize_simple_input`), so an
# out-of-scope id is dropped from the result set — but `humanize_value` was left
# doing a bare unscoped `association_class.where(id: ids)`, resolving and rendering
# the HIDDEN record's `to_label` into the pill. The same crafted URL that the
# normalized path silently rejects still surfaced the out-of-scope record's name
# via the raw-params path.
#
# These tests assert the FIXED behaviour: `humanize_value` honours `@scope_proc`
# (mirroring the arity-aware `apply_scope` shared by ResourceSelect and Typeahead),
# so out-of-scope ids resolve to nothing and the pill is suppressed by
# `active_filter_descriptions`'s `next if humanized.blank?` guard.
#
# `Catalog::Category` is the shipped fixture: it has a non-null `name` column and
# `to_label` (Plutonium::Resource::Record::Labeling) returns that `name` — so a
# leak surfaces a genuinely sensitive value, not the id the attacker supplied.
class AssociationScopeLeakTest < ActiveSupport::TestCase
  setup do
    @included_cat = Catalog::Category.create!(name: "Public Category")
    @excluded_cat = Catalog::Category.create!(name: "Internal Confidential Category")
  end

  teardown do
    purge_data!
  end

  # Builds a filter narrowed to the in-scope category via the documented
  # arity-1 Proc form (`->(s) { s.where(...) }`), matching how the bug report
  # and `test_customize_inputs_forwards_scope_proc_to_input` exercise the scope.
  def category_filter(scope: default_scope)
    Plutonium::Query::Filters::Association.new(
      key: :category, class_name: Catalog::Category, scope: scope
    )
  end

  def default_scope
    ->(s) { s.where(id: @included_cat.id) }
  end

  # ===========================================================================
  # Scope-honouring: the core of the fix
  # ===========================================================================

  def test_humanize_value_returns_empty_string_for_out_of_scope_id
    # The bug: this returned "Internal Confidential Category" — the hidden
    # record's label — despite the scope excluding it.
    assert_equal "", category_filter.humanize_value(@excluded_cat.id.to_s)
  end

  def test_humanize_value_returns_label_for_in_scope_id
    assert_equal "Public Category", category_filter.humanize_value(@included_cat.id.to_s)
  end

  def test_humanize_value_returns_only_in_scope_labels_for_mixed_ids
    result = category_filter.humanize_value([@included_cat.id.to_s, @excluded_cat.id.to_s])

    assert_equal "Public Category", result
    refute_includes result, "Internal Confidential Category"
  end

  # ===========================================================================
  # Scope-form parity with ResourceSelect#apply_scope / Typeahead#apply_scope
  # ===========================================================================
  # The arity-aware dispatch (Symbol / arity-0 Proc / arity-1 Proc / nil) must
  # stay in lock-step with those two helpers; any divergence re-opens the leak.

  def test_humanize_value_honours_zero_arity_proc_scope_kanban_form
    # The kanban form `-> { where(...) }` runs via `relation.instance_exec(&scope)`,
    # which rebinds `self` to the relation inside the proc — so values needed
    # by the scope must be captured in locals, not ivars (the ivar would resolve
    # against the relation, where it doesn't exist). This mirrors how a real
    # `scope :verified` is written: a closed-over literal, not a controller ivar.
    included_id = @included_cat.id
    scope = -> { where(id: included_id) }
    filter = category_filter(scope: scope)

    assert_equal "Public Category", filter.humanize_value(@included_cat.id.to_s)
    assert_equal "", filter.humanize_value(@excluded_cat.id.to_s)
  end

  def test_humanize_value_honours_one_arity_proc_scope_documented_form
    # The documented form `->(s) { s.where(...) }` runs via `scope.call(relation)`.
    scope = ->(s) { s.where(id: @included_cat.id) }
    filter = category_filter(scope: scope)

    assert_equal "Public Category", filter.humanize_value(@included_cat.id.to_s)
    assert_equal "", filter.humanize_value(@excluded_cat.id.to_s)
  end

  # ===========================================================================
  # SGID path (the new default sent by ResourceSelect)
  # ===========================================================================
  # `decode_id` recognises SignedGlobalIDs and returns the underlying model id.
  # Out-of-scope SGIDs must resolve to nothing — not fall through `rescue` to
  # echo the raw token, nor render the hidden record's label.

  def test_humanize_value_returns_empty_for_out_of_scope_sgid
    sgid = @excluded_cat.to_signed_global_id.to_s

    assert_equal "", category_filter.humanize_value(sgid)
  end

  def test_humanize_value_returns_label_for_in_scope_sgid
    sgid = @included_cat.to_signed_global_id.to_s

    assert_equal "Public Category", category_filter.humanize_value(sgid)
  end

  # ===========================================================================
  # Backwards compatibility: no `scope:` config still resolves any id
  # ===========================================================================
  # Pre-4bbe82b4 behaviour was *consistent* — nothing enforced the scope, so
  # every id resolved. The fix must not regress the (deliberately unscoped)
  # filter; only ever narrow when `scope:` is set.

  def test_humanize_value_with_no_scope_resolves_any_id
    filter = Plutonium::Query::Filters::Association.new(
      key: :category, class_name: Catalog::Category, scope: nil
    )

    assert_equal "Public Category", filter.humanize_value(@included_cat.id.to_s)
    assert_equal "Internal Confidential Category", filter.humanize_value(@excluded_cat.id.to_s)
  end

  # ===========================================================================
  # End-to-end: QueryObject#active_filter_descriptions (the raw-params path)
  # ===========================================================================
  # `Plutonium::Resource::QueryObject` is built from `raw_resource_query_params`
  # (`params[:q].to_unsafe_h`), so the pill renderer reads the RAW, un-normalized
  # value and calls `humanize_value` directly. A crafted `?q[category][value]=<id>`
  # must not surface an out-of-scope record's name as a chip.

  def test_active_filter_descriptions_does_not_surface_out_of_scope_chip
    query_object = Plutonium::Resource::QueryObject.new(
      Object, {category: {value: @excluded_cat.id.to_s}}, "/catalog/products"
    ) do |qo|
      qo.define_filter(:category, Plutonium::Query::Filters::Association.new(
        key: :category, class_name: Catalog::Category, scope: default_scope
      ))
    end

    descriptions = query_object.active_filter_descriptions
    cat_desc = descriptions.find { |d| d[:name] == :category }

    # The chip must NOT be surfaced for an out-of-scope id — that's the leak.
    # `humanize_value` returns "" (blank), and `active_filter_descriptions`
    # skips via `next if humanized.blank?`.
    assert_nil cat_desc, "an active filter chip was surfaced for an out-of-scope id"
  end

  def test_active_filter_descriptions_surfaces_in_scope_chip
    query_object = Plutonium::Resource::QueryObject.new(
      Object, {category: {value: @included_cat.id.to_s}}, "/catalog/products"
    ) do |qo|
      qo.define_filter(:category, Plutonium::Query::Filters::Association.new(
        key: :category, class_name: Catalog::Category, scope: default_scope
      ))
    end

    descriptions = query_object.active_filter_descriptions
    cat_desc = descriptions.find { |d| d[:name] == :category }

    assert cat_desc, "expected an active filter chip for the in-scope id"
    assert_equal "Public Category", cat_desc[:value_label]
    # The label is what FilterPills#render_pill interpolates verbatim into the
    # rendered HTML: `span { plain "#{filter[:label]}: #{filter[:value_label]}" }`.
    refute_equal "Internal Confidential Category", cat_desc[:value_label]
  end
end
