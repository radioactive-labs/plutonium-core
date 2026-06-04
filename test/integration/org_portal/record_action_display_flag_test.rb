# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Reproduction: a record-typed interactive action (interaction has
# `attribute :resource`) declared with `record_action: false` so it shows on
# collection rows only (collection_record_action? stays true). Triggering it
# from a row must build the commit URL against the row's RECORD, not the class.
# Previously form_action keyed the subject off record_action? alone, so it
# passed the resource class and built a nonexistent plural collection helper.
class OrgPortal::RecordActionDisplayFlagTest < ActionDispatch::IntegrationTest
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

  test "GET record action with record_action:false renders form with record-scoped commit URL" do
    get "#{prefix}/catalog/products/#{@product.id}/record_actions/collect_spec_row",
      headers: {"Turbo-Frame" => "remote_modal"}
    assert_response :success
    form_action = response.body[/<form[^>]*action="([^"]*)"/, 1]
    assert_equal "#{prefix}/catalog/products/#{@product.id}/record_actions/collect_spec_row", form_action
  end
end
