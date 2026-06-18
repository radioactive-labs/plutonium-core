# frozen_string_literal: true

require "test_helper"

# handle_signup_submission must look up the existing account with a normalized
# login so the "an account with this email already exists, sign in instead"
# guard works case-insensitively. Otherwise a mixed-case typed email skips the
# guard and falls through to a uniqueness error swallowed into a generic flash.
class Plutonium::Invites::SignupSubmissionTest < Minitest::Test
  # Bare host that includes the concern. Collaborators are stubbed so we can
  # drive the private handler directly without routes/views.
  class Host < ActionController::Base
    include Plutonium::Invites::Controller

    attr_accessor :stub_params, :stub_user_class

    def params = stub_params
    def user_class = stub_user_class
    def render(*) = nil
    def flash = @flash ||= Struct.new(:now).new({})
  end

  def build_invite(enforce_email:, email: nil)
    invite = Object.new
    invite.define_singleton_method(:enforce_email?) { enforce_email }
    invite.define_singleton_method(:email) { email }
    invite
  end

  # Spy user class whose find_by records the email it was queried with and
  # returns a truthy "existing user" so the guard short-circuits.
  def spy_user_class
    Class.new do
      class << self
        attr_accessor :captured_email
        def find_by(email:)
          self.captured_email = email
          Object.new
        end
      end
    end
  end

  def test_existing_user_guard_downcases_a_typed_mixed_case_email
    host = Host.new
    host.instance_variable_set(:@invite, build_invite(enforce_email: false))
    host.stub_params = {email: "Foo@Bar.COM", password: "pw", password_confirmation: "pw"}
    spy = spy_user_class
    host.stub_user_class = spy

    host.send(:handle_signup_submission)

    assert_equal "foo@bar.com", spy.captured_email
  end
end
