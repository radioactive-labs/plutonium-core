# frozen_string_literal: true

require "test_helper"
require_relative "shared"

class Plutonium::Wizard::Store::ActiveRecordTest < ActiveSupport::TestCase
  include WizardStoreBehavior

  setup do
    @store = Plutonium::Wizard::Store::ActiveRecord.new
    Plutonium::Wizard::Session.delete_all
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
end
