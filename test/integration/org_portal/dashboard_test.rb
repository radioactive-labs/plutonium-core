# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# A dashboard on a `:path` entity-scoped portal: page and card URLs carry the
# tenant segment, and card blocks see `current_scoped_entity`.
class OrgPortal::DashboardTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!(name: "Acme Corp")
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    create_membership!(organization: @org, user: create_user!)
    login_as(@user, portal: :user)
  end

  def base = "/org/#{@org.to_param}/team"

  test "frames point at the scoped card endpoint" do
    get base
    assert_response :success
    frame = response.body[/<turbo-frame[^>]*\bid="pu-dashboard-card-members"[^>]*>/]
    assert frame
    assert_includes frame, %(src="#{base}/cards/members")
    assert_match(%r{href="#{Regexp.escape(base)}"[^>]*>.*?Team}m, response.body)
  end

  test "cards run inside the tenant" do
    get "#{base}/cards/members", headers: {"Turbo-Frame" => "pu-dashboard-card-members"}
    assert_response :success
    assert_match(/pu-metric-value[^>]*>2</, response.body)

    get "#{base}/cards/name", headers: {"Turbo-Frame" => "pu-dashboard-card-name"}
    assert_match(/<p>Acme Corp<\/p>/, response.body)
  end

  test "another tenant's dashboard is not reachable" do
    other = create_organization!
    get "/org/#{other.to_param}/team"
    assert_response :not_found
  end
end
