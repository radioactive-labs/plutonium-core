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

  private

  def build_controller_class(mod)
    Class.new(ActionController::Base) do
      include mod

      # Stub rodauth method to avoid actual Rodauth dependency
      def rodauth(name = nil)
        @mock_rodauth ||= Struct.new(:rails_account, :logout_path, :url_options=).new(nil, "/logout", nil)
      end
    end
  end
end
