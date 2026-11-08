# frozen_string_literal: true

require "test_helper"

class Plutonium::Rbac::InviteTest < ActiveSupport::TestCase
  INVITE_TABLE = :rbac_test_invites
  MEMBERSHIP_TABLE = :rbac_test_memberships
  USER_TABLE = :rbac_test_users

  class TestUser < ActiveRecord::Base
    self.table_name = USER_TABLE.to_s
  end

  class TestMembership < ActiveRecord::Base
    self.table_name = MEMBERSHIP_TABLE.to_s
    include Plutonium::Rbac::Holder
    belongs_to :user, class_name: "Plutonium::Rbac::InviteTest::TestUser", optional: true
  end

  class TestInvite < ActiveRecord::Base
    self.table_name = INVITE_TABLE.to_s
    include Plutonium::Invites::Concerns::InviteToken
    include Plutonium::Rbac::Invite

    belongs_to :user, class_name: "Plutonium::Rbac::InviteTest::TestUser", optional: true
    belongs_to :invitable, polymorphic: true, optional: true

    class_attribute :fail_membership, default: false

    # The test invite has no tenant.
    def entity = nil

    def send_invitation_email
    end

    def enforce_email? = false

    def create_membership_for(user)
      raise ActiveRecord::RecordInvalid.new(TestMembership.new) if fail_membership

      TestMembership.create!(user_id: user.id, role: role)
    end
  end

  class TestInviteUser < Plutonium::Interaction::Base
    include Plutonium::Invites::Concerns::InviteUser
    include Plutonium::Rbac::InviteUser
  end

  setup do
    ActiveRecord::Base.with_connection do |c|
      c.create_table USER_TABLE, force: true do |t|
        t.string :email
      end
      c.create_table MEMBERSHIP_TABLE, force: true do |t|
        t.belongs_to :user
        t.integer :role
      end
      c.create_table INVITE_TABLE, force: true do |t|
        t.string :email
        t.string :token
        t.integer :state, default: 0
        t.integer :role, default: 0
        t.datetime :expires_at
        t.datetime :accepted_at
        t.belongs_to :user
        t.belongs_to :invitable, polymorphic: true
      end
    end
    Plutonium::Rbac::Current.reset
    Plutonium::Rbac::RoleAssignment.delete_all
    Plutonium::Rbac::Role.delete_all
    @role = Plutonium::Rbac::Role.create!(name: "Editor", permissions: ["hr/employee.update"])
  end

  teardown do
    TestInvite.fail_membership = false
    Plutonium::Rbac::Current.reset
    Plutonium::Rbac::RoleAssignment.delete_all
    Plutonium::Rbac::Role.delete_all
    ActiveRecord::Base.with_connection do |c|
      c.drop_table INVITE_TABLE, if_exists: true
      c.drop_table MEMBERSHIP_TABLE, if_exists: true
      c.drop_table USER_TABLE, if_exists: true
    end
  end

  def create_invite!(email)
    TestInvite.create!(email:, token: SecureRandom.urlsafe_base64(16), state: :pending, rbac_role_ids: [@role.id])
  end

  test "an invite is a holder" do
    invite = create_invite!("a@example.com")
    assert_equal [@role.id], invite.rbac_role_assignments.pluck(:role_id)
    assert_equal Set["hr/employee.update"], invite.rbac_permission_keys
  end

  test "assignments move to the membership on accept" do
    invite = create_invite!("a@example.com")
    user = TestUser.create!(email: "a@example.com")
    invite.accept_for_user!(user)

    membership = TestMembership.find_by!(user_id: user.id)
    assert_equal [@role.id], membership.rbac_role_assignments.pluck(:role_id)
    assert_empty invite.rbac_role_assignments.reload
  end

  test "failed membership creation keeps assignments on the invite" do
    invite = create_invite!("b@example.com")
    TestInvite.fail_membership = true

    assert_raises(ActiveRecord::RecordInvalid) do
      invite.accept_for_user!(TestUser.create!(email: "b@example.com"))
    end

    assert_equal [@role.id], invite.rbac_role_assignments.reload.pluck(:role_id)
    assert_equal 0, TestMembership.count
  end

  test "transfer rolls back when the notification step fails after the move" do
    invite = create_invite!("c@example.com")
    invite.define_singleton_method(:notify_invitable) { |_user| raise ActiveRecord::RecordInvalid.new(TestMembership.new) }
    user = TestUser.create!(email: "c@example.com")

    assert_raises(ActiveRecord::RecordInvalid) { invite.accept_for_user!(user) }

    assert_equal [@role.id], invite.rbac_role_assignments.reload.pluck(:role_id)
    assert_equal 0, TestMembership.count
  end

  test "InviteUser passes rbac_role_ids through additional_invite_attributes" do
    interaction = TestInviteUser.new(view_context: nil, rbac_role_ids: [@role.id])
    assert_equal [@role.id], interaction.send(:additional_invite_attributes)[:rbac_role_ids]
  end
end
