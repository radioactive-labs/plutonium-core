# frozen_string_literal: true

require "test_helper"

class Plutonium::Invites::ControllerTest < Minitest::Test
  PLUTONIUM_ROOT_VIEWS = File.expand_path("app/views", Plutonium.root)

  def test_controller_concern_appends_plutonium_views
    klass = Class.new(ActionController::Base) do
      include Plutonium::Invites::Controller
    end

    paths = klass.view_paths.map { |p| p.to_s.chomp("/") }
    assert_includes paths, PLUTONIUM_ROOT_VIEWS.chomp("/")
  end

  def test_pending_invite_check_concern_appends_plutonium_views
    klass = Class.new(ActionController::Base) do
      include Plutonium::Invites::PendingInviteCheck
    end

    paths = klass.view_paths.map { |p| p.to_s.chomp("/") }
    assert_includes paths, PLUTONIUM_ROOT_VIEWS.chomp("/")
  end

  def test_invitation_path_for_is_overridable
    klass = Class.new(ActionController::Base) do
      include Plutonium::Invites::Controller

      def invitation_path_for(token)
        "/funder_invitations/#{token}"
      end
    end

    instance = klass.new
    assert_equal "/funder_invitations/abc", instance.send(:invitation_path_for, "abc")
  end
end
