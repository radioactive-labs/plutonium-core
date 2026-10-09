# frozen_string_literal: true

require "test_helper"

class Plutonium::Auth::RodauthTest < ActiveSupport::TestCase
  test "for creates a module with expected methods" do
    mod = Plutonium::Auth::Rodauth.for(:user)

    assert_kind_of Module, mod
  end

  test "module includes current_user as helper method" do
    mod = Plutonium::Auth::Rodauth.for(:user)
    controller_class = build_controller_class(mod)

    assert_includes controller_class._helper_methods, :current_user
  end

  test "module includes logout_url as helper method" do
    mod = Plutonium::Auth::Rodauth.for(:user)
    controller_class = build_controller_class(mod)

    assert_includes controller_class._helper_methods, :logout_url
  end

  test "module includes profile_url as helper method" do
    mod = Plutonium::Auth::Rodauth.for(:user)
    controller_class = build_controller_class(mod)

    assert_includes controller_class._helper_methods, :profile_url
  end

  test "profile_url returns nil by default" do
    mod = Plutonium::Auth::Rodauth.for(:user)
    controller_class = build_controller_class(mod)
    controller = controller_class.new

    result = controller.send(:profile_url)

    assert_nil result
  end

  test "profile_url can be overridden" do
    mod = Plutonium::Auth::Rodauth.for(:user)
    controller_class = build_controller_class(mod)
    controller_class.class_eval do
      def profile_url
        "/custom/profile"
      end
    end
    controller = controller_class.new

    result = controller.send(:profile_url)

    assert_equal "/custom/profile", result
  end

  test "module to_s includes rodauth name" do
    mod = Plutonium::Auth::Rodauth.for(:admin)

    assert_equal "Plutonium::Auth::Rodauth(:admin)", mod.to_s
  end

  test "module inspect includes rodauth name" do
    mod = Plutonium::Auth::Rodauth.for(:admin)

    assert_equal "Plutonium::Auth::Rodauth(:admin)", mod.inspect
  end

  test "does not define a named current_<account> alias" do
    # The named alias (e.g. current_admin) was removed: it collided with
    # other context accessors (e.g. current_parent / entity-scoped helpers).
    # Only current_user is exposed.
    mod = Plutonium::Auth::Rodauth.for(:admin)
    controller_class = build_controller_class(mod)
    controller = controller_class.new

    refute_includes controller_class._helper_methods, :current_admin
    refute_respond_to controller, :current_admin
  end

  test "for(:user) still defines current_user without error" do
    mod = Plutonium::Auth::Rodauth.for(:user)
    controller_class = build_controller_class(mod)

    assert_includes controller_class._helper_methods, :current_user
  end

  test "a valid JWT verifies the request without a CSRF token" do
    controller = build_forgery_controller(features: [:jwt], valid_jwt: true).new

    assert controller.send(:verified_request?)
  end

  test "an invalid JWT does not verify the request" do
    controller = build_forgery_controller(features: [:jwt], valid_jwt: false).new

    refute controller.send(:verified_request?)
  end

  test "without the jwt feature the CSRF token check decides" do
    controller = build_forgery_controller(features: [:login], valid_jwt: true).new

    refute controller.send(:verified_request?)
  end

  private

  def build_forgery_controller(features:, valid_jwt:)
    rodauth = Struct.new(:features, :valid_jwt?).new(features, valid_jwt)
    # Stands in for Rails' token check, which fails: no token was sent.
    unverified = Class.new(ActionController::Base) do
      def verified_request? = false
    end

    Class.new(unverified) do
      include Plutonium::Auth::Rodauth.for(:user)

      define_method(:rodauth) { |name = nil| rodauth }
    end
  end

  def build_controller_class(mod)
    Class.new(ActionController::Base) do
      include mod

      # Stub rodauth method to avoid actual Rodauth dependency
      def rodauth(name = nil)
        @mock_rodauth ||= Struct.new(:rails_account, :logout_path, :url_options).new(nil, "/logout", nil)
      end
    end
  end
end
