# frozen_string_literal: true

require "test_helper"

class Plutonium::Wizard::InstanceKeyTest < Minitest::Test
  IK = Plutonium::Wizard::InstanceKey

  def gid(type, id) = "gid://dummy/#{type}/#{id}"

  # --- tokened identity (no concurrency_key) ---

  def test_tokened_is_deterministic
    a = IK.tokened("W", "tok-1")
    b = IK.tokened("W", "tok-1")
    assert_equal a, b
  end

  def test_tokened_distinguishes_token
    refute_equal IK.tokened("W", "tok-1"), IK.tokened("W", "tok-2")
  end

  def test_tokened_distinguishes_wizard
    refute_equal IK.tokened("A", "tok"), IK.tokened("B", "tok")
  end

  def test_tokened_matches_recipe
    expected = Digest::SHA256.hexdigest(["tokened", "W", "abc"].join("|"))
    assert_equal expected, IK.tokened("W", "abc")
  end

  # --- concurrency identity (with concurrency_key) ---

  def test_concurrency_is_deterministic
    a = IK.concurrency("W", ["user-1", "tenant-1"])
    b = IK.concurrency("W", ["user-1", "tenant-1"])
    assert_equal a, b
  end

  def test_concurrency_distinguishes_key
    refute_equal IK.concurrency("W", ["user-1"]), IK.concurrency("W", ["user-2"])
  end

  def test_concurrency_folds_tenant_distinct
    # Same user, different tenants → different keys (tenancy fold, §4.4).
    refute_equal(
      IK.concurrency("W", ["user-1", gid("Org", 1)]),
      IK.concurrency("W", ["user-1", gid("Org", 2)])
    )
  end

  def test_concurrency_distinguishes_wizard
    refute_equal IK.concurrency("A", ["k"]), IK.concurrency("B", ["k"])
  end

  def test_tokened_and_concurrency_never_collide
    refute_equal IK.tokened("W", "k"), IK.concurrency("W", ["k"])
  end

  # --- serialization ---

  def test_serialize_array_joins_elements
    obj = Struct.new(:gid) { def to_global_id = gid }.new("gid://dummy/Company/9")
    assert_equal "gid://dummy/Company/9|x", IK.serialize([obj, "x"])
  end

  def test_serialize_nil_is_blank
    assert_equal "", IK.serialize(nil)
    # A nil tenant folds to a stable blank, not the literal "nil".
    assert_equal "user-1|", IK.serialize(["user-1", nil])
  end

  def test_serialize_record_uses_global_id
    obj = Struct.new(:gid) { def to_global_id = gid }.new("gid://dummy/Company/9")
    assert_equal "gid://dummy/Company/9", IK.serialize(obj)
  end

  def test_serialize_scalar
    assert_equal "42", IK.serialize(42)
    assert_equal "free", IK.serialize(:free)
  end
end
