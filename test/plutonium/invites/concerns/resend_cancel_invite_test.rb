# frozen_string_literal: true

require "test_helper"

# The resend / cancel interactions read their labels and messages from
# config/locales/en/invites.yml.
class Plutonium::Invites::Concerns::ResendCancelInviteTest < ActiveSupport::TestCase
  class Resend < Plutonium::Interaction::Base
    include Plutonium::Invites::Concerns::ResendInvite
  end

  class Cancel < Plutonium::Interaction::Base
    include Plutonium::Invites::Concerns::CancelInvite
  end

  Invite = Struct.new(:email, :pending) do
    def pending? = pending
  end

  test "labels resolve lazily from the locale" do
    assert_equal "Resend Invitation", Plutonium::Translation.resolve(Resend.label)
    assert_equal "Cancel Invitation", Plutonium::Translation.resolve(Cancel.label)
  end

  test "resend interpolates the email into the success message and rejects non-pending invites" do
    interaction = Resend.new(view_context: nil, resource: Invite.new("foo@bar.com", false))

    assert_equal "Invitation resent to foo@bar.com", interaction.send(:success_message)
    assert interaction.execute.failure?
    assert_equal ["Can only resend pending invitations"], interaction.errors[:base]
  end

  test "cancel rejects non-pending invites with the translated message" do
    interaction = Cancel.new(view_context: nil, resource: Invite.new("foo@bar.com", false))

    assert_equal "Invitation cancelled", interaction.send(:success_message)
    assert interaction.execute.failure?
    assert_equal ["Can only cancel pending invitations"], interaction.errors[:base]
  end
end
