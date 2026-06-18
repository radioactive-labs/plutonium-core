# frozen_string_literal: true

require "test_helper"

# The InviteUser interaction's dedup guards (user_not_already_member,
# no_pending_invitation) and the invite it creates must all use a normalized
# login, otherwise a differently-cased email evades the guards and produces
# duplicate invitations / missed "already a member" checks.
class Plutonium::Invites::Concerns::InviteUserTest < ActiveSupport::TestCase
  class TestInviteUser < Plutonium::Interaction::Base
    include Plutonium::Invites::Concerns::InviteUser
  end

  test "normalizes the email attribute to lowercase" do
    interaction = TestInviteUser.new(view_context: nil, email: "Foo@Bar.COM")

    assert_equal "foo@bar.com", interaction.email
  end

  test "leaves a nil email untouched" do
    interaction = TestInviteUser.new(view_context: nil)

    assert_nil interaction.email
  end
end
