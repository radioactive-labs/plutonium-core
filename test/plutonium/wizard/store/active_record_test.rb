# frozen_string_literal: true

require "test_helper"
require_relative "shared"

class Plutonium::Wizard::Store::ActiveRecordTest < ActiveSupport::TestCase
  include WizardStoreBehavior

  # A NAMED wizard fixture so the store can resolve `encrypt_data?` from the row's
  # stored class name. (The shared contract's synthetic "W" can't be constantized,
  # which exercises the "unresolvable → treated as clear" path.)
  class StoreEncryptingWizard < Plutonium::Wizard::Base
    encrypt_data
  end

  setup do
    @store = Plutonium::Wizard::Store::ActiveRecord.new
    Plutonium::Wizard::Session.delete_all
    # Configure encryption with deterministic test keys (Rails-conventional: keys
    # live in the suite, not per-test). The unconfigured path is driven by a stub.
    ActiveRecord::Encryption.configure(
      primary_key: "a" * 32, deterministic_key: "b" * 32, key_derivation_salt: "c" * 32
    )
  end

  test "an encrypt_data wizard stores its data as an encrypted envelope and reads it back" do
    st = build_state(wizard: StoreEncryptingWizard.name, data: {"account" => {"email" => "ada@example.com"}})
    @store.write(st.instance_key, st, cleanup_after: 1.day)

    raw = Plutonium::Wizard::Session.find_by!(instance_key: st.instance_key).data
    assert_equal [Plutonium::Wizard::Store::ActiveRecord::ENCRYPTED_ENVELOPE_KEY], raw.keys,
      "the data column holds only the encrypted envelope"
    refute_includes raw.to_json, "ada@example.com", "no plaintext field value is stored at rest"

    got = @store.read(st.instance_key)
    assert_equal({"account" => {"email" => "ada@example.com"}}, got.data, "read decrypts the envelope")
  end

  test "a non-encrypting wizard stores its data in clear (no envelope)" do
    st = build_state(wizard: "W", data: {"a" => 1})
    @store.write(st.instance_key, st, cleanup_after: 1.day)
    raw = Plutonium::Wizard::Session.find_by!(instance_key: st.instance_key).data
    assert_equal({"a" => 1}, raw)
  end

  test "encrypt_data with unconfigured encryption raises a wizard-named error" do
    # Simulate an unconfigured key set by overriding the encryptor to raise the
    # same Configuration error ActiveRecord raises lazily; restore it after.
    raising = Object.new
    def raising.encrypt(*) = raise ActiveRecord::Encryption::Errors::Configuration, "key provider not configured"
    ActiveRecord::Encryption.define_singleton_method(:encryptor) { raising }

    st = build_state(wizard: StoreEncryptingWizard.name, data: {"a" => 1})
    err = assert_raises(ActiveRecord::Encryption::Errors::Configuration) do
      @store.write(st.instance_key, st, cleanup_after: 1.day)
    end
    assert_match(/StoreEncryptingWizard/, err.message)
    assert_match(/not configured/, err.message)
  ensure
    ActiveRecord::Encryption.singleton_class.send(:remove_method, :encryptor)
  end

  test "write stamps expires_at = now + cleanup_after" do
    st = build_state
    freeze_time do
      @store.write(st.instance_key, st, cleanup_after: 3.days)
      row = Plutonium::Wizard::Session.find_by!(instance_key: st.instance_key)
      assert_in_delta (Time.current + 3.days).to_f, row.expires_at.to_f, 1.0
    end
  end

  test "write with nil cleanup_after leaves expires_at null" do
    st = build_state
    @store.write(st.instance_key, st, cleanup_after: nil)
    row = Plutonium::Wizard::Session.find_by!(instance_key: st.instance_key)
    assert_nil row.expires_at
  end

  test "write persists polymorphic owner columns" do
    owner = make_owner
    st = build_state(owner: owner)
    @store.write(st.instance_key, st, cleanup_after: 1.day)
    row = Plutonium::Wizard::Session.find_by!(instance_key: st.instance_key)
    assert_equal owner, row.owner
  end

  test "complete stamps completed_at" do
    st = build_state
    @store.write(st.instance_key, st, cleanup_after: 1.day)
    @store.complete(st.instance_key)
    row = Plutonium::Wizard::Session.find_by!(instance_key: st.instance_key)
    refute_nil row.completed_at
    assert row.status_completed?
  end

  test "sweepable scope selects expired in_progress and stale completing rows" do
    now = Time.current
    grace = Plutonium::Wizard::Session::COMPLETING_GRACE
    expired = create_session(instance_key: "expired", status: "in_progress", expires_at: now - 1.hour)
    create_session(instance_key: "fresh", status: "in_progress", expires_at: now + 1.hour)
    create_session(instance_key: "never", status: "in_progress", expires_at: nil)
    create_session(instance_key: "done", status: "completed", expires_at: now - 1.hour)

    # A `completing` row is swept only once it has been completing longer than the
    # grace window (a CRASHED finalize) — never while a finalize may still be
    # running `execute` (a recent `updated_at`), which would destroy its records.
    stale = create_session(instance_key: "stale-completing", status: "completing", expires_at: now - 1.hour)
    stale.update_column(:updated_at, now - (grace + 1.minute))
    create_session(instance_key: "recent-completing", status: "completing", expires_at: now - 1.hour)

    keys = Plutonium::Wizard::Session.sweepable(now).pluck(:instance_key)
    assert_includes keys, expired.instance_key
    assert_includes keys, stale.instance_key
    refute_includes keys, "fresh"
    refute_includes keys, "never"
    refute_includes keys, "done"
    refute_includes keys, "recent-completing"
  end

  # Two requests read the same run at version 0, then both write. Without the
  # locked version-aware merge the later writer would clobber the earlier
  # advance (last-writer-wins); with it, both survive (§6.2 / Fix C20).
  test "a stale write merges instead of clobbering a concurrent advance" do
    seed = build_state(data: {"one" => {"x" => "1"}})
    @store.write(seed.instance_key, seed, cleanup_after: 1.day) # creates v0
    read_a = @store.read(seed.instance_key)                     # v0
    read_b = @store.read(seed.instance_key)                     # v0

    # Request A advances step "two" (no concurrent writer yet → verbatim, → v1).
    read_a.data = read_a.data.merge("two" => {"y" => "2"})
    @store.write(read_a.instance_key, read_a, cleanup_after: 1.day) do |latest|
      latest.data = latest.data.deep_merge(read_a.data)
      latest
    end

    # Request B is still at v0 but the row is now v1 → the store must MERGE B's
    # "three" onto A's committed state, not drop A's "two".
    read_b.data = read_b.data.merge("three" => {"z" => "3"})
    @store.write(read_b.instance_key, read_b, cleanup_after: 1.day) do |latest|
      latest.data = latest.data.deep_merge(read_b.data)
      latest
    end

    final = @store.read(seed.instance_key).data
    assert_equal "2", final.dig("two", "y"), "concurrent advance A must survive"
    assert_equal "3", final.dig("three", "z"), "advance B must survive"
  end

  private

  def create_session(**attrs)
    Plutonium::Wizard::Session.create!({wizard: "W"}.merge(attrs))
  end

  def make_owner
    Organization.create!(name: "Org-#{SecureRandom.hex(4)}")
  end

  def make_scope
    Organization.create!(name: "Scope-#{SecureRandom.hex(4)}")
  end
end
