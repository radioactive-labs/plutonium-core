# frozen_string_literal: true

require "test_helper"

class Plutonium::Invites::PendingInviteCheckTest < Minitest::Test
  # Stub invite class that emulates `find_for_acceptance`.
  class StubInvite
    @valid_tokens = {}

    class << self
      attr_accessor :valid_tokens

      def find_for_acceptance(token)
        valid_tokens[token]
      end
    end
  end

  class OtherInvite < StubInvite
    @valid_tokens = {}
  end

  # Bare host that includes the concern. Inherits ActionController::Base so the
  # concern's `append_view_path` (added by `included do`) has somewhere to run.
  class Host < ActionController::Base
    include Plutonium::Invites::PendingInviteCheck

    attr_accessor :_invite_classes

    def cookies
      @cookies ||= Class.new {
        def encrypted
          @encrypted ||= {}
        end

        def delete(_key)
        end
      }.new
    end

    def invite_classes
      _invite_classes
    end
  end

  def setup
    StubInvite.valid_tokens = {}
    OtherInvite.valid_tokens = {}
  end

  def test_finds_invite_in_first_class
    invite = Object.new
    StubInvite.valid_tokens["t1"] = invite

    host = Host.new
    host._invite_classes = [StubInvite, OtherInvite]
    host.cookies.encrypted[:pending_invitation] = "t1"

    assert_equal invite, host.send(:pending_invite)
  end

  def test_finds_invite_in_second_class_when_first_misses
    invite = Object.new
    OtherInvite.valid_tokens["t2"] = invite

    host = Host.new
    host._invite_classes = [StubInvite, OtherInvite]
    host.cookies.encrypted[:pending_invitation] = "t2"

    assert_equal invite, host.send(:pending_invite)
  end

  def test_returns_nil_when_no_class_finds
    host = Host.new
    host._invite_classes = [StubInvite, OtherInvite]
    host.cookies.encrypted[:pending_invitation] = "missing"

    assert_nil host.send(:pending_invite)
  end

  def test_invite_class_singular_override_still_works
    invite = Object.new
    StubInvite.valid_tokens["t3"] = invite

    legacy_host = Class.new(ActionController::Base) {
      include Plutonium::Invites::PendingInviteCheck

      def cookies
        @cookies ||= Class.new {
          def encrypted
            @encrypted ||= {pending_invitation: "t3"}
          end

          def delete(_key)
          end
        }.new
      end

      def invite_class
        StubInvite
      end
    }.new

    assert_equal invite, legacy_host.send(:pending_invite)
  end
end
