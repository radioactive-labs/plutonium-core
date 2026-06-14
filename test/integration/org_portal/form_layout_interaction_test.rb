# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Verifies that interaction forms respect form_layout: sections are rendered
# with their headings, while input names remain unchanged (sections only add
# wrapper divs). PublishProduct declares form_layout with a :details section
# containing :reference and :file.
class OrgPortal::FormLayoutInteractionTest < ActionDispatch::IntegrationTest
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

  test "interaction form renders form_layout sections" do
    get "#{prefix}/catalog/products/#{@product.id}/record_actions/publish",
      headers: {"Turbo-Frame" => "remote_modal"}
    assert_response :success
    assert_includes response.body, "Details"                          # section heading
    assert_includes response.body, %(name="interaction[reference]")   # field still renders, name unchanged
  end
end
