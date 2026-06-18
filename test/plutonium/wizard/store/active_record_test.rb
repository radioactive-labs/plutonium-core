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

  test "sweepable scope selects expired in_progress/completing rows" do
    now = Time.current
    expired = create_session(instance_key: "expired", status: "in_progress", expires_at: now - 1.hour)
    create_session(instance_key: "fresh", status: "in_progress", expires_at: now + 1.hour)
    create_session(instance_key: "never", status: "in_progress", expires_at: nil)
    create_session(instance_key: "done", status: "completed", expires_at: now - 1.hour)
    completing = create_session(instance_key: "completing", status: "completing", expires_at: now - 1.hour)

    keys = Plutonium::Wizard::Session.sweepable(now).pluck(:instance_key)
    assert_includes keys, expired.instance_key
    assert_includes keys, completing.instance_key
    refute_includes keys, "fresh"
    refute_includes keys, "never"
    refute_includes keys, "done"
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
