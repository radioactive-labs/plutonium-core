# frozen_string_literal: true

require "test_helper"

# The invite stores the email exactly as typed by the inviter. Lookups elsewhere
# (account_from_login, find_by(email:)) downcase, and the DB may be
# case-sensitive, so the invite must be normalized at the source.
class Plutonium::Invites::Concerns::InviteTokenTest < ActiveSupport::TestCase
  TABLE = :invite_token_test_invites

  class TestInvite < ActiveRecord::Base
    self.table_name = TABLE.to_s
    include Plutonium::Invites::Concerns::InviteToken

    # Mailer is not configured in this unit test; keep after_commit a no-op.
    def send_invitation_email
    end
  end

  def setup
    ActiveRecord::Base.connection.create_table TABLE, force: true do |t|
      t.string :email
      t.string :token
      t.integer :state, default: 0
      t.datetime :expires_at
      t.datetime :accepted_at
    end
  end

  def teardown
    ActiveRecord::Base.connection.drop_table TABLE, if_exists: true
  end

  test "downcases the email before validation" do
    invite = TestInvite.new(email: "Foo@Bar.COM")

    invite.valid?

    assert_equal "foo@bar.com", invite.email
  end

  test "persists the normalized email" do
    invite = TestInvite.create!(email: "Mixed@Case.com")

    assert_equal "mixed@case.com", invite.reload.email
  end

  test "leaves a blank email alone (presence validation handles it)" do
    invite = TestInvite.new(email: nil)

    invite.valid?

    assert_nil invite.email
  end
end
