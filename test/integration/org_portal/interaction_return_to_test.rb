# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Regression: an interactive-action form must never carry a `return_to` that
# points at the action's own (modal-only) URL. When it did, a successful commit
# "returned" to the bare form rendered standalone outside the modal frame = a
# blank page. The form now carries only an explicit return_to; when absent the
# controller computes the right destination (resource_url_for).
class OrgPortal::InteractionReturnToTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @category = create_category!
    @product = create_product!(category: @category, user: @user, organization: @org, status: :draft)
    login_as(@user, portal: :user)
  end

  def prefix = "/org/#{@org.to_param}"

  def return_to_value(body)
    body[/name="return_to"[^>]*\bvalue="([^"]*)"/, 1] ||
      body[/\bvalue="([^"]*)"[^>]*name="return_to"/, 1]
  end

  test "form does not emit a self-referential return_to when no param is supplied" do
    get "#{prefix}/catalog/products/#{@product.id}/record_actions/publish",
      headers: {"Turbo-Frame" => "remote_modal"}

    assert_response :success
    value = return_to_value(response.body)
    # Either no value at all, or definitely not the action's own URL.
    assert value.blank?, "expected a blank return_to, got #{value.inspect}"
    refute_match %r{record_actions}, response.body.scan(/name="return_to"[^>]*>/).join
  end

  test "form honors an explicitly supplied return_to param" do
    show = "#{prefix}/catalog/products/#{@product.id}"
    get "#{prefix}/catalog/products/#{@product.id}/record_actions/publish",
      params: {return_to: show},
      headers: {"Turbo-Frame" => "remote_modal"}

    assert_response :success
    assert_equal show, return_to_value(response.body)
  end

  test "commit with no return_to redirects to the resource, not the action URL" do
    show_path = "#{prefix}/catalog/products/#{@product.id}"

    post "#{prefix}/catalog/products/#{@product.id}/record_actions/publish",
      headers: {
        "Referer" => "http://www.example.com#{prefix}/catalog/products/#{@product.id}/record_actions/publish",
        "Accept" => "text/vnd.turbo-stream.html"
      }

    assert_response :success
    assert_match %r{<turbo-stream[^>]*action="redirect"}, response.body
    refute_match %r{<turbo-stream[^>]*action="refresh"}, response.body
    assert_match %r{url="[^"]*#{Regexp.escape(show_path)}"}, response.body
    refute_match %r{record_actions}, response.body
  end
end
