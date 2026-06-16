# frozen_string_literal: true

# Shared behavior contract every wizard Store adapter must satisfy.
# Host test cases must define #build_state(wizard:, instance_key:, data:, **) and
# set @store in setup.
module WizardStoreBehavior
  def test_write_then_read_roundtrip
    st = build_state(data: {"a" => 1}, visited: ["one"])
    @store.write(st.instance_key, st, cleanup_after: 1.day)
    got = @store.read(st.instance_key)
    refute_nil got
    assert_equal({"a" => 1}, got.data)
    assert_equal ["one"], got.visited
    assert_equal "in_progress", got.status
    assert_equal "W", got.wizard
    assert_equal st.instance_key, got.instance_key
  end

  def test_read_missing_returns_nil
    assert_nil @store.read("does-not-exist")
  end

  def test_write_upserts_by_instance_key
    st = build_state(data: {"a" => 1})
    @store.write(st.instance_key, st, cleanup_after: 1.day)
    st2 = build_state(data: {"a" => 2})
    st2.instance_key = st.instance_key
    @store.write(st.instance_key, st2, cleanup_after: 1.day)
    assert_equal({"a" => 2}, @store.read(st.instance_key).data)
  end

  def test_complete_sets_status_and_nulls_payload
    st = build_state(data: {"a" => 1})
    @store.write(st.instance_key, st, cleanup_after: 1.day)
    @store.complete(st.instance_key)
    got = @store.read(st.instance_key)
    assert_equal "completed", got.status
    assert_empty got.data
    assert_empty got.persisted
    assert_empty got.visited
  end

  def test_completed_query
    st = build_state
    @store.write(st.instance_key, st, cleanup_after: 1.day)
    refute @store.completed?(instance_key: st.instance_key)
    @store.complete(st.instance_key)
    assert @store.completed?(instance_key: st.instance_key)
    refute @store.completed?(instance_key: "some-other-key")
  end

  def test_clear_removes_the_row
    st = build_state
    @store.write(st.instance_key, st, cleanup_after: 1.day)
    @store.clear(st.instance_key)
    assert_nil @store.read(st.instance_key)
  end

  def test_in_progress_for_owner
    owner = make_owner
    st = build_state(owner: owner)
    @store.write(st.instance_key, st, cleanup_after: 1.day)
    states = @store.in_progress_for(owner, scope: nil)
    assert_equal 1, states.size
    assert_equal st.instance_key, states.first.instance_key

    @store.complete(st.instance_key)
    assert_empty @store.in_progress_for(owner, scope: nil)
  end

  def test_in_progress_for_owner_narrows_by_scope
    owner = make_owner
    scope_a = make_scope
    scope_b = make_scope

    in_a = build_state(owner: owner, scope: scope_a, data: {"x" => "a"})
    in_b = build_state(owner: owner, scope: scope_b, data: {"x" => "b"})
    @store.write(in_a.instance_key, in_a, cleanup_after: 1.day)
    @store.write(in_b.instance_key, in_b, cleanup_after: 1.day)

    # No scope → both.
    assert_equal 2, @store.in_progress_for(owner, scope: nil).size

    # Scoped → only that scope's row.
    scoped = @store.in_progress_for(owner, scope: scope_a)
    assert_equal 1, scoped.size
    assert_equal in_a.instance_key, scoped.first.instance_key
  end

  private

  def build_state(wizard: "W", data: {}, owner: nil, **extra)
    Plutonium::Wizard::State.new(
      wizard: wizard,
      instance_key: "key-#{wizard}-#{data.hash}-#{owner&.object_id}",
      current_step: "one",
      data: data,
      persisted: {},
      owner: owner,
      **extra
    )
  end

  # Overridden by AR test to supply a persisted record; memory store accepts anything.
  def make_owner = "owner-#{object_id}-#{rand(1_000_000)}"

  # Overridden by AR test to supply a persisted scope record; memory store accepts anything.
  def make_scope = "scope-#{object_id}-#{rand(1_000_000)}"
end
