# frozen_string_literal: true

require "test_helper"

class Plutonium::Rodauth::ControllerMethodsTest < ActiveSupport::TestCase
  test "root_path falls back to login_redirect when main_app has no root route" do
    refute Rails.application.routes.url_helpers.respond_to?(:root_path),
      "dummy app must not define a root route for this test"

    controller = build_controller(login_redirect: "/dashboard")

    assert_equal "/dashboard", controller.send(:root_path)
  end

  test "root_path returns main_app.root_path when defined" do
    with_root_route do
      controller = build_controller(login_redirect: "/dashboard")

      assert_equal "/", controller.send(:root_path)
    end
  end

  private

  def build_controller(login_redirect:)
    klass = Class.new(ActionController::Base) do
      include Plutonium::Rodauth::ControllerMethods
    end
    rodauth_stub = Struct.new(:login_redirect).new(login_redirect)
    controller = klass.new
    controller.define_singleton_method(:rodauth) { |_name = nil| rodauth_stub }
    controller.request = ActionDispatch::TestRequest.create
    controller
  end

  def with_root_route
    Rails.application.routes.draw do
      root to: proc { [200, {}, ["ok"]] }
    end
    yield
  ensure
    Rails.application.reload_routes!
  end
end
