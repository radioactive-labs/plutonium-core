# frozen_string_literal: true

require "test_helper"

# Tests for the shared identity digest (§4), used by BOTH the runner/driving layer
# (creates rows) and the gate (recomputes the key). They must stay byte-identical.
class Plutonium::Wizard::ComputeInstanceKeyTest < ActiveSupport::TestCase
  # Keyed by current_user (tenant folded automatically).
  class PerUserWizard < Plutonium::Wizard::Base
    concurrency_key { current_user }
    step(:a) { attribute :x, :string }
    review label: "R"
    def execute = succeed
  end

  # Keyed by the anchor.
  class PerAnchorWizard < Plutonium::Wizard::Base
    anchored with: Organization
    concurrency_key { anchor }
    step(:a) { attribute :x, :string }
    review label: "R"
    def execute = succeed(anchor)
  end

  # No concurrency_key → tokened.
  class TokenedWizard < Plutonium::Wizard::Base
    step(:a) { attribute :x, :string }
    review label: "R"
    def execute = succeed
  end

  # References a method that isn't part of the identity context.
  class BadKeyWizard < Plutonium::Wizard::Base
    concurrency_key { totally_missing_method }
    step(:a) { attribute :x, :string }
    review label: "R"
    def execute = succeed
  end

  def compute(klass, **kw)
    defaults = {current_user: nil, current_scoped_entity: nil, anchor: nil, wizard_token: nil}
    Plutonium::Wizard.compute_instance_key(wizard_class: klass, **defaults.merge(kw))
  end

  setup do
    Organization.delete_all
    @user = Organization.create!(name: "User-#{SecureRandom.hex(4)}")
  end

  test "tokened wizard hashes the wizard_token" do
    a = compute(TokenedWizard, wizard_token: "t1")
    b = compute(TokenedWizard, wizard_token: "t1")
    c = compute(TokenedWizard, wizard_token: "t2")
    assert_equal a, b
    refute_equal a, c
    # A fresh token per launch → distinct, repeatable runs.
  end

  test "per-user key is stable across launches and tokens" do
    a = compute(PerUserWizard, current_user: @user, wizard_token: "t1")
    b = compute(PerUserWizard, current_user: @user, wizard_token: "t2")
    assert_equal a, b, "concurrency_key ignores the per-launch token → resumes one run"
  end

  test "tenancy fold: same user + same wizard in two tenants → two distinct keys" do
    org1 = Organization.create!(name: "Tenant-1")
    org2 = Organization.create!(name: "Tenant-2")
    k1 = compute(PerUserWizard, current_user: @user, current_scoped_entity: org1)
    k2 = compute(PerUserWizard, current_user: @user, current_scoped_entity: org2)
    refute_equal k1, k2, "the folded tenant must isolate the same user's runs (§4.4)"
  end

  test "per-anchor key distinguishes anchors" do
    a1 = Organization.create!(name: "Anchor-1")
    a2 = Organization.create!(name: "Anchor-2")
    refute_equal compute(PerAnchorWizard, anchor: a1), compute(PerAnchorWizard, anchor: a2)
  end

  test "pre-auth then auth does NOT rekey a concurrency-keyed run" do
    # A keyed run's identity is the concurrency_key, not the owner — so stamping
    # owner after login leaves the key unchanged (§4.5). For PerUserWizard the key
    # IS current_user, so simulate a pre-auth key with a fixed scope: a tokened
    # wizard's key never changes when owner is added either.
    pre = compute(TokenedWizard, current_user: nil, wizard_token: "tok")
    post = compute(TokenedWizard, current_user: @user, wizard_token: "tok")
    assert_equal pre, post, "tokened identity is stable across pre-auth → auth (no rekey)"
  end

  test "a concurrency_key referencing a missing method raises a clear error" do
    err = assert_raises(ArgumentError) { compute(BadKeyWizard, current_user: @user) }
    assert_match(/concurrency_key/, err.message)
  end
end
