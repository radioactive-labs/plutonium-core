# frozen_string_literal: true

require "test_helper"

class Plutonium::Wizard::InstanceKeyTest < Minitest::Test
  def key(**kw) = Plutonium::Wizard::InstanceKey.for(**kw)

  def gid(type, id) = "gid://dummy/#{type}/#{id}"

  def test_token_excludes_owner
    with_token = key(wizard: "W", scope: nil, anchor: nil, token: "abc", owner: nil)
    after_auth = key(wizard: "W", scope: nil, anchor: nil, token: "abc", owner: gid("User", 1))
    assert_equal with_token, after_auth, "owner must not change the digest when a token is present"
  end

  def test_owner_principal_without_token
    a = key(wizard: "W", scope: nil, anchor: nil, token: nil, owner: gid("User", 1))
    b = key(wizard: "W", scope: nil, anchor: nil, token: nil, owner: gid("User", 2))
    refute_equal a, b
  end

  def test_scope_distinguishes
    a = key(wizard: "W", scope: gid("Org", 1), anchor: nil, token: nil, owner: gid("User", 1))
    b = key(wizard: "W", scope: gid("Org", 2), anchor: nil, token: nil, owner: gid("User", 1))
    refute_equal a, b
  end

  def test_anchor_distinguishes
    a = key(wizard: "W", scope: nil, anchor: gid("Company", 1), token: nil, owner: gid("User", 1))
    b = key(wizard: "W", scope: nil, anchor: gid("Company", 2), token: nil, owner: gid("User", 1))
    refute_equal a, b
  end

  def test_wizard_distinguishes
    a = key(wizard: "A", scope: nil, anchor: nil, token: "t", owner: nil)
    b = key(wizard: "B", scope: nil, anchor: nil, token: "t", owner: nil)
    refute_equal a, b
  end

  def test_deterministic
    a = key(wizard: "W", scope: nil, anchor: nil, token: nil, owner: gid("User", 1))
    b = key(wizard: "W", scope: nil, anchor: nil, token: nil, owner: gid("User", 1))
    assert_equal a, b
  end

  def test_matches_sha256_recipe
    expected = Digest::SHA256.hexdigest(["W", "", "", "abc"].join("|"))
    assert_equal expected, key(wizard: "W", scope: nil, anchor: nil, token: "abc", owner: nil)
  end

  def test_blank_token_falls_back_to_owner
    blank_token = key(wizard: "W", scope: nil, anchor: nil, token: "", owner: gid("User", 1))
    no_token = key(wizard: "W", scope: nil, anchor: nil, token: nil, owner: gid("User", 1))
    assert_equal no_token, blank_token, "a blank token should fall back to the owner principal"
  end

  def test_objects_resolved_via_global_id
    gid_string = Struct.new(:str) { def to_s = str }.new("gid://dummy/Company/9")
    obj = Struct.new(:gid) { def to_global_id = gid }.new(gid_string)
    via_object = key(wizard: "W", scope: nil, anchor: obj, token: "t", owner: nil)
    via_string = key(wizard: "W", scope: nil, anchor: "gid://dummy/Company/9", token: "t", owner: nil)
    assert_equal via_string, via_object
  end
end
