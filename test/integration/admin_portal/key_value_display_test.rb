# frozen_string_literal: true

require "test_helper"

# KitchenSinkDefinition declares `field :prefs, as: :key_value`: the form gets
# the key/value editor, the show page and table the key/value list.
class AdminPortal::KeyValueDisplayTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    login_as_admin(create_admin!)
    @sink = KitchenSink.create!(name: "Sink", organization: Organization.create!(name: "Org #{SecureRandom.hex(4)}"),
      prefs: {"newsletter" => "weekly", "theme" => "dark"})
  end

  def pairs
    Nokogiri::HTML(response.body).css("dl.key_value > dt, dl.key_value > dd").map { |node| node.text.strip }
  end

  test "the show page lists the pairs" do
    get "/admin/kitchen_sinks/#{@sink.id}"

    assert_response :success
    assert_equal %w[newsletter weekly theme dark], pairs
  end

  test "the edit form keeps the key/value editor" do
    get "/admin/kitchen_sinks/#{@sink.id}/edit"

    assert_includes response.body, 'data-controller="key-value-store"'
  end
end
