# frozen_string_literal: true

require "test_helper"

# `InviteToken#accept_for_user!` must serialize concurrent acceptances so a
# single invite creates exactly one membership — even when `enforce_email?` is
# false and any logged-in user may accept. The re-check of `pending?` inside
# `with_lock` closes the TOCTOU window between `find_for_acceptance` (which
# checks `pending?` unlocked) and the state-flipping UPDATE.
#
# The concurrent-thread test at the bottom needs real row locks (PostgreSQL);
# SQLite does not honor `SELECT ... FOR UPDATE`, so it is gated. The
# sequential simulation tests below are the deterministic regression guard and
# run on the default SQLite CI matrix.
class Plutonium::Invites::Concerns::InviteTokenAcceptanceTest < ActiveSupport::TestCase
  INVITE_TABLE = :acceptance_test_invites
  MEMBERSHIP_TABLE = :acceptance_test_memberships
  USER_TABLE = :acceptance_test_users
  INVITABLE_TABLE = :acceptance_test_invitables

  class TestUser < ActiveRecord::Base
    self.table_name = USER_TABLE.to_s
  end

  class TestMembership < ActiveRecord::Base
    self.table_name = MEMBERSHIP_TABLE.to_s
    belongs_to :user, class_name: "Plutonium::Invites::Concerns::InviteTokenAcceptanceTest::TestUser", optional: true
  end

  # A real AR invitable so the polymorphic association persists and
  # `on_invite_accepted` records which user it was notified about.
  class TestInvitable < ActiveRecord::Base
    self.table_name = INVITABLE_TABLE.to_s

    class << self
      attr_accessor :notifications
    end

    def on_invite_accepted(user)
      self.class.notifications << user.id
    end
  end

  class TestInvite < ActiveRecord::Base
    self.table_name = INVITE_TABLE.to_s
    include Plutonium::Invites::Concerns::InviteToken

    belongs_to :user, class_name: "Plutonium::Invites::Concerns::InviteTokenAcceptanceTest::TestUser", optional: true
    belongs_to :invitable, polymorphic: true, optional: true

    def send_invitation_email
    end

    attr_writer :enforce_email

    def enforce_email?
      defined?(@enforce_email) ? @enforce_email : true
    end

    def create_membership_for(user)
      TestMembership.create!(user_id: user.id, role: role)
    end
  end

  def setup
    ActiveRecord::Base.connection.create_table USER_TABLE, force: true do |t|
      t.string :email
    end
    ActiveRecord::Base.connection.create_table MEMBERSHIP_TABLE, force: true do |t|
      t.belongs_to :user
      t.integer :role
    end
    ActiveRecord::Base.connection.create_table INVITABLE_TABLE, force: true do |t|
      t.string :name
    end
    ActiveRecord::Base.connection.create_table INVITE_TABLE, force: true do |t|
      t.string :email
      t.string :token
      t.integer :state, default: 0
      t.integer :role, default: 0
      t.datetime :expires_at
      t.datetime :accepted_at
      t.belongs_to :user
      t.belongs_to :invitable, polymorphic: true
    end
    TestInvitable.notifications = []
  end

  def teardown
    ActiveRecord::Base.connection.drop_table INVITE_TABLE, if_exists: true
    ActiveRecord::Base.connection.drop_table MEMBERSHIP_TABLE, if_exists: true
    ActiveRecord::Base.connection.drop_table USER_TABLE, if_exists: true
    ActiveRecord::Base.connection.drop_table INVITABLE_TABLE, if_exists: true
  end

  def create_invite!(email: "alice@example.com", enforce_email: true, role: 0, invitable: nil)
    invite = TestInvite.create!(
      email: email,
      token: SecureRandom.urlsafe_base64(16),
      state: :pending,
      role: role
    )
    invite.enforce_email = enforce_email
    invite.update!(invitable: invitable) if invitable
    invite
  end

  def create_user!(email)
    TestUser.create!(email: email)
  end

  # ---- happy path -----------------------------------------------------------

  test "accepts a pending invite and creates exactly one membership" do
    invite = create_invite!(email: "alice@example.com", enforce_email: true)
    user = create_user!("alice@example.com")

    invite.accept_for_user!(user)

    invite.reload
    assert invite.accepted?, "invite should be accepted after a happy-path acceptance"
    assert_equal user.id, invite.user_id
    assert_not_nil invite.accepted_at
    assert_equal 1, TestMembership.count, "exactly one membership should be created"
    membership = TestMembership.first
    assert_equal user.id, membership.user_id
    assert_equal 0, membership.role
  end

  test "notifies the invitable exactly once on acceptance" do
    invitable = TestInvitable.create!(name: "Profile")
    invite = create_invite!(invitable: invitable)
    user = create_user!(invite.email)
    invite.enforce_email = false  # already set, but keep explicit

    invite.accept_for_user!(user)

    assert_equal [user.id], TestInvitable.notifications,
      "invitable#on_invite_accepted should fire once for the accepting user"
  end

  test "acceptance does not notify when no invitable is set" do
    invite = create_invite!
    user = create_user!(invite.email)

    invite.accept_for_user!(user)

    assert_empty TestInvitable.notifications
  end

  # ---- email constraints are still enforced before any lock/state change ----

  test "raises RecordInvalid with the email error when enforce_email? mismatches" do
    invite = create_invite!(enforce_email: true)
    other_user = create_user!("someone_else@example.com")

    error = assert_raises(ActiveRecord::RecordInvalid) do
      invite.accept_for_user!(other_user)
    end

    assert_match(/invitation is for/, error.record.errors.full_messages.join(", "))
    refute invite.accepted?, "a failed email constraint must not flip state"
    assert_equal 0, TestMembership.count, "no membership should be created on email mismatch"
  end

  test "allow any email when enforce_email? is false" do
    invite = create_invite!(enforce_email: false)
    any_user = create_user!("someone_else@example.com")

    invite.accept_for_user!(any_user)

    invite.reload
    assert invite.accepted?
    assert_equal any_user.id, invite.user_id
    assert_equal 1, TestMembership.count
  end

  # ---- the race fix: an already-accepted invite cannot be accepted again --

  test "re-accepting an already-accepted invite raises RecordInvalid and creates no duplicate membership" do
    invite = create_invite!(enforce_email: false)
    winner = create_user!("winner@example.com")
    loser = create_user!("loser@example.com")

    invite.accept_for_user!(winner)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      invite.reload.accept_for_user!(loser)
    end

    assert_match(/already been accepted/, error.record.errors.full_messages.join(", "))
    assert error.record.errors.added?(:base, "This invitation has already been accepted"),
      "the :base error should carry the already-accepted message"

    invite.reload
    assert_equal winner.id, invite.user_id, "the losing user must not overwrite the winning user"
    assert_equal 1, TestMembership.count, "no duplicate membership should be created for the loser"
    assert_equal winner.id, TestMembership.first.user_id
  end

  test "a second different user cannot create a membership from one invite when enforce_email? is false" do
    # The disclosed exploit: open invites + two concurrent users. Simulate the
    # winner having committed before the loser calls accept_for_user!, which is
    # exactly the state the row-lock re-check observes in production.
    invite = create_invite!(enforce_email: false)
    user_a = create_user!("a@example.com")
    user_b = create_user!("b@example.com")

    invite.accept_for_user!(user_a)

    assert_raises(ActiveRecord::RecordInvalid) { invite.reload.accept_for_user!(user_b) }

    invite.reload
    assert invite.accepted?
    assert_equal [user_a.id], TestMembership.pluck(:user_id),
      "only the first user should gain a membership from a single invite"
  end

  test "the loser does not fire on_invite_accepted for the invitable" do
    invitable = TestInvitable.create!(name: "Profile")
    invite = create_invite!(enforce_email: false, invitable: invitable)
    winner = create_user!("winner@example.com")
    loser = create_user!("loser@example.com")

    invite.accept_for_user!(winner)
    assert_raises(ActiveRecord::RecordInvalid) { invite.reload.accept_for_user!(loser) }

    assert_equal [winner.id], TestInvitable.notifications,
      "the invitable should be notified exactly once, for the winner only"
  end

  test "re-accepting raises RecordInvalid even after the invite row is stale (optimistic view)" do
    invite = create_invite!(enforce_email: false)
    user_a = create_user!("a@example.com")
    user_b = create_user!("b@example.com")

    # A different in-memory instance for user_b, mirroring two controller
    # requests each finding the invite via find_for_acceptance independently.
    invite_for_b = TestInvite.find(invite.id)

    invite.accept_for_user!(user_a)

    assert_raises(ActiveRecord::RecordInvalid) do
      invite_for_b.accept_for_user!(user_b)
    end

    assert_equal 1, TestMembership.count
  end

  # ---- a cancellation/expiry is also refused (defense in depth) -----------

  test "accepting an invite that has been cancelled raises RecordInvalid and creates no membership" do
    invite = create_invite!(enforce_email: false)
    user = create_user!("x@example.com")

    invite.update!(state: :cancelled)

    assert_raises(ActiveRecord::RecordInvalid) { invite.reload.accept_for_user!(user) }
    assert_equal 0, TestMembership.count
  end

  # ---- true concurrent acceptance: requires real row locks (PostgreSQL) ----

  test "two concurrent threads accept the same invite for different users and only one wins" do
    unless ActiveRecord::Base.connection.adapter_name.match?(/post/i)
      skip "requires PostgreSQL row locks (SELECT ... FOR UPDATE); SQLite serializes writes " \
           "without locking and so cannot exercise this race faithfully"
    end

    invite = create_invite!(enforce_email: false)
    user_a = create_user!("a@example.com")
    user_b = create_user!("b@example.com")

    # Classic two-process start barrier: both threads block on the IVar until
    # the main thread fulfills it, so they hit the row lock as close together
    # as possible.
    barrier = Concurrent::IVar.new
    errors = Concurrent::Array.new

    threads = [
      Thread.new do
        barrier.value
        begin
          invite.accept_for_user!(user_a)
        rescue => e
          errors << e
        end
      end,
      Thread.new do
        barrier.value
        begin
          TestInvite.find(invite.id).accept_for_user!(user_b)
        rescue => e
          errors << e
        end
      end
    ]

    # Let both threads park on the barrier before releasing, then join.
    sleep 0.2
    barrier.set true
    threads.each(&:join)

    invite.reload
    assert invite.accepted?, "the invite should end up accepted by exactly one user"
    assert_equal 1, TestMembership.count, "exactly one membership should be created from a single invite"
    assert_includes [user_a.id, user_b.id], invite.user_id
    # The loser must surface a RecordInvalid (the controller renders :forbidden
    # from it), not a silent no-op or a different exception.
    assert(errors.any? { |e| e.is_a?(ActiveRecord::RecordInvalid) },
      "one thread should lose the lock and raise RecordInvalid: #{errors.inspect}")
  end
end
