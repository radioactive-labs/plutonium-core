# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# KitchenSinkDefinition declares `filter :labels, with: :tags`.
class TagsFilterTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  def filter_options
    Nokogiri::HTML(response.body).css("select[name='q[labels][value][]'] option").map(&:text)
  end

  def row_names
    Nokogiri::HTML(response.body).css("tbody tr").map(&:text).join(" ")
  end

  test "the admin index filters by tag" do
    login_as_admin(create_admin!)
    org = Organization.create!(name: "Org #{SecureRandom.hex(4)}")
    KitchenSink.create!(name: "Tagged", organization: org, labels_list: %w[steel])
    KitchenSink.create!(name: "Untagged", organization: org)

    get "/admin/kitchen_sinks", params: {"q[labels][value][]" => "steel"}

    assert_response :success
    assert_includes row_names, "Tagged"
    refute_includes row_names, "Untagged"
  end

  test "a tenant only sees its own tags as filter options" do
    org = create_organization!
    user = create_user!
    create_membership!(organization: org, user: user)
    KitchenSink.create!(name: "Mine", organization: org, labels_list: %w[ours])
    KitchenSink.create!(name: "Theirs", organization: create_organization!, labels_list: %w[secret-project])
    login_as(user, portal: :user)

    get "/org/#{org.to_param}/kitchen_sinks"

    assert_response :success
    assert_includes filter_options, "ours"
    refute_includes filter_options, "secret-project"
  end
end
