# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::ResourceSelectTest < Minitest::Test
  def test_choices_uses_raw_choices_when_provided
    user_choices = [["Alice", "1"], ["Bob", "2"]]
    component = build_component(raw_choices: user_choices)

    mapper = component.send(:choices)

    assert_equal user_choices, mapper.instance_variable_get(:@collection)
  end

  def test_choices_falls_back_to_association_class_all_when_no_raw_choices
    relation = Object.new
    component = build_component(association_class: stub_class(relation))

    mapper = component.send(:choices)

    assert_equal relation, mapper.instance_variable_get(:@collection)
  end

  def test_choices_returns_empty_when_no_raw_choices_and_no_association_class
    component = build_component

    mapper = component.send(:choices)

    assert_equal [], mapper.instance_variable_get(:@collection)
  end

  def test_normalize_simple_input_accepts_sgid_in_unbounded_relation
    in_scope = User.create!(email: "rs-in-#{SecureRandom.hex(4)}@example.com", password: "password123")
    component = build_component(association_class: User)
    sgid = in_scope.to_signed_global_id.to_s

    # `choices` is capped at choice_limit but normalize_simple_input now
    # consults the unbounded User.all relation.
    assert_equal sgid, component.send(:normalize_simple_input, sgid)
  end

  def test_normalize_simple_input_rejects_sgid_for_wrong_class
    org = Organization.create!(name: "rs-org-#{SecureRandom.hex(4)}")
    component = build_component(association_class: User)

    assert_nil component.send(:normalize_simple_input, org.to_signed_global_id.to_s)
  end

  def test_normalize_simple_input_returns_nil_for_blank_or_garbage
    component = build_component(association_class: User)

    assert_nil component.send(:normalize_simple_input, nil)
    assert_nil component.send(:normalize_simple_input, "")
    assert_nil component.send(:normalize_simple_input, "garbage")
  end

  def test_normalize_simple_input_falls_back_to_choices_when_raw_choices_provided
    permitted_user = User.create!(email: "rs-perm-#{SecureRandom.hex(4)}@example.com", password: "password123")
    rejected_user = User.create!(email: "rs-rej-#{SecureRandom.hex(4)}@example.com", password: "password123")
    permitted_sgid = permitted_user.to_signed_global_id.to_s

    component = build_component(raw_choices: [permitted_sgid], association_class: User)

    assert_equal permitted_sgid, component.send(:normalize_simple_input, permitted_sgid)
    assert_nil component.send(:normalize_simple_input, rejected_user.to_signed_global_id.to_s)
  end

  # typeahead_searchable? — proves the auto opt-out hook reaches into
  # FALLBACK_SEARCH_COLUMNS, so a model with a `name` column is
  # auto-eligible without anyone declaring `search`.

  def test_typeahead_searchable_false_when_no_association_class
    component = build_component
    refute component.send(:typeahead_searchable?)
  end

  def test_typeahead_searchable_true_when_model_has_fallback_column
    component = build_component(association_class: Organization)
    assert component.send(:typeahead_searchable?)
  end

  def test_typeahead_searchable_false_when_model_has_no_fallback_column
    # OrganizationUser has no name/title/label/etc. column.
    component = build_component(association_class: OrganizationUser)
    refute component.send(:typeahead_searchable?)
  end

  # detect_typeahead_kind_and_name — proves the filter-vs-input
  # detection via :q lineage. This is non-obvious behavior that would
  # silently regress if Phlexi's DOM internals shift.

  def test_detect_kind_and_name_returns_input_when_no_q_ancestor
    field = stub_field([stub_node(:user_form), stub_node(:organization)])
    component = build_component
    component.instance_variable_set(:@field, field)

    assert_equal [:input, :organization], component.send(:detect_typeahead_kind_and_name)
  end

  def test_detect_kind_and_name_returns_filter_when_q_ancestor_present
    # Lineage shape that Plutonium::UI::Form::Query produces:
    # form root -> :q -> filter name -> :value
    field = stub_field([stub_node(:filter_form), stub_node(:q), stub_node(:status), stub_node(:value)])
    component = build_component
    component.instance_variable_set(:@field, field)

    assert_equal [:filter, :status], component.send(:detect_typeahead_kind_and_name)
  end

  # ==================== apply_scope dispatch ====================
  # Regression for the silent-no-op bug: @scope was never consumed. These
  # prove ResourceSelect applies a scope (Symbol/Proc/nil), mirroring the
  # kanban Grouping.apply_scope pattern, with arity-based Proc dispatch so
  # BOTH the documented `->(s) { s.verified }` form AND the zero-arg kanban
  # form `-> { where(...) }` work.

  def test_apply_scope_with_symbol_calls_named_scope
    verified = create_scoped_user(status: :verified)
    unverified = create_scoped_user(status: :unverified)
    component = build_component(association_class: User)

    scoped = component.send(:apply_scope, User.all, :verified).where(id: [verified.id, unverified.id])

    assert_includes scoped, verified
    refute_includes scoped, unverified
  ensure
    [verified, unverified].each { |u| u&.destroy }
  end

  def test_apply_scope_with_proc_taking_relation_arg
    # Documented form: ->(s) { s.verified }
    verified = create_scoped_user(status: :verified)
    unverified = create_scoped_user(status: :unverified)
    component = build_component(association_class: User)

    scoped = component.send(:apply_scope, User.all, ->(s) { s.verified }).where(id: [verified.id, unverified.id])

    assert_includes scoped, verified
    refute_includes scoped, unverified
  ensure
    [verified, unverified].each { |u| u&.destroy }
  end

  def test_apply_scope_with_zero_arity_proc_uses_instance_exec
    # Kanban form: -> { where(status: <value>) } (self is the relation)
    verified = create_scoped_user(status: :verified)
    unverified = create_scoped_user(status: :unverified)
    component = build_component(association_class: User)

    scoped = component.send(:apply_scope, User.all, -> { where(status: :verified) }).where(id: [verified.id, unverified.id])

    assert_includes scoped, verified
    refute_includes scoped, unverified
  ensure
    [verified, unverified].each { |u| u&.destroy }
  end

  def test_apply_scope_with_nil_returns_relation_unchanged
    relation = User.all
    component = build_component(association_class: User)

    assert_same relation, component.send(:apply_scope, relation, nil)
  end

  def test_apply_scope_with_unsupported_type_raises_argument_error
    component = build_component(association_class: User)

    error = assert_raises(ArgumentError) do
      component.send(:apply_scope, User.all, 42)
    end
    assert_match(/Unsupported association scope/, error.message)
  end

  # ==================== authorized_relation applies the scope ====================
  # Proves the scope narrows the dropdown's candidate set BEFORE
  # authorization, and that omitting a scope keeps the ( capped ) .all set —
  # i.e. no regression for the no-scope happy path.

  def test_authorized_relation_applies_proc_scope_to_choices
    verified = create_scoped_user(status: :verified)
    unverified = create_scoped_user(status: :unverified)
    component = build_component(association_class: User, scope: ->(s) { s.verified })

    relation = component.send(:authorized_relation)

    assert_includes relation, verified
    refute_includes relation, unverified
  ensure
    [verified, unverified].each { |u| u&.destroy }
  end

  def test_authorized_relation_applies_symbol_scope_to_choices
    verified = create_scoped_user(status: :verified)
    unverified = create_scoped_user(status: :unverified)
    component = build_component(association_class: User, scope: :verified)

    relation = component.send(:authorized_relation)

    assert_includes relation, verified
    refute_includes relation, unverified
  ensure
    [verified, unverified].each { |u| u&.destroy }
  end

  def test_authorized_relation_without_scope_returns_unscoped_all
    verified = create_scoped_user(status: :verified)
    unverified = create_scoped_user(status: :unverified)
    component = build_component(association_class: User, scope: nil)

    relation = component.send(:authorized_relation)

    assert_includes relation, verified
    assert_includes relation, unverified
  ensure
    [verified, unverified].each { |u| u&.destroy }
  end

  def test_authorized_relation_applies_scope_before_limit
    # Scope narrows BEFORE the choice_limit cap, so the cap applies to the
    # scoped set, not the broader .all. With 4 verified + 1 unverified and a
    # limit of 3, the result is 3 verified records (capped from the 4
    # verified) — never 3 records drawn from .all that could include
    # unverified rows. Proves BOTH that the scope is honoured AND that the
    # limit runs after it (a no-scope limit-3 would surface unverified rows).
    verified = 4.times.map { create_scoped_user(status: :verified) }
    unverified = create_scoped_user(status: :unverified)
    component = build_component(association_class: User, scope: :verified)
    limit = 3
    component.instance_variable_set(:@choice_limit, limit)

    relation = component.send(:authorized_relation, limit: limit)

    rows = relation.to_a
    assert_equal limit, rows.length
    assert(rows.all? { |r| r.status == "verified" }, "expected only verified rows; got statuses: #{rows.map(&:status).inspect}")
    refute_includes rows, unverified
    assert_equal verified.sort_by(&:id).first(limit), rows.sort_by(&:id)
  ensure
    verified&.each { |u| u&.destroy }
    unverified&.destroy
  end

  private

  def create_scoped_user(status:)
    User.create!(email: "rs-scope-#{SecureRandom.hex(4)}@example.com", password: "password123", status: status)
  end

  def stub_node(key)
    node = Object.new
    node.define_singleton_method(:key) { key }
    node
  end

  def stub_field(lineage)
    dom = Object.new
    dom.define_singleton_method(:lineage) { lineage }
    field = Object.new
    field.define_singleton_method(:dom) { dom }
    field.define_singleton_method(:key) { lineage.last.key }
    field
  end

  def build_component(raw_choices: nil, association_class: nil, scope: nil)
    component = Plutonium::UI::Form::Components::ResourceSelect.allocate
    component.instance_variable_set(:@raw_choices, raw_choices)
    component.instance_variable_set(:@association_class, association_class)
    # Skip the authorized_resource_scope path — it calls view_context,
    # which is unavailable outside a render cycle.
    component.instance_variable_set(:@skip_authorization, true)
    component.instance_variable_set(:@scope, scope)
    component.instance_variable_set(:@choice_limit, nil)
    # Stub resource_definition for the typeahead_searchable? path; in a
    # real render this resolves through view_context.controller.
    component.define_singleton_method(:resource_definition) do |klass|
      "#{klass.name}Definition".constantize.new
    end
    component
  end

  def stub_class(relation)
    klass = Class.new
    klass.define_singleton_method(:all) { relation }
    klass
  end
end
