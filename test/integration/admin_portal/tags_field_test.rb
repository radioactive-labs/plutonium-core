# frozen_string_literal: true

require "test_helper"

# KitchenSink `has_tags :labels` / `:zones` (restrict_to_existing, limit 2),
# scoped per organization. The policy permits them by context name; nothing
# is declared in the definition.
class AdminPortal::TagsFieldTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    login_as_admin(create_admin!)
    @org = Organization.create!(name: "Org #{SecureRandom.hex(4)}")
    @sink = KitchenSink.create!(name: "Sink", organization: @org, labels_list: %w[steel])
    KitchenSink.const_get(:KitchenSinkTag).create!(name: "kitchen", organization_id: @org.id)
  end

  def update(**attributes)
    patch "/admin/kitchen_sinks/#{@sink.id}", params: {kitchen_sink: {name: "Sink", **attributes}}
  end

  test "the edit form renders the chip input for each context" do
    get "/admin/kitchen_sinks/#{@sink.id}/edit"

    page = Nokogiri::HTML(response.body)
    assert_equal %w[steel kitchen], page.css("select[name='kitchen_sink[labels][]'] option").map(&:text)
    assert page.at_css("select[name='kitchen_sink[zones][]']")
  end

  test "submitted tags are saved, typed ones created" do
    update(labels: ["", "steel", "brushed"])

    assert_equal %w[steel brushed].sort, @sink.reload.labels_list.to_a.sort
  end

  test "removing every chip clears the tags" do
    update(labels: [""])

    assert_empty @sink.reload.labels_list.to_a
  end

  # The input offers only existing tags, so an unknown one can only be forged;
  # like any select, the form drops values that aren't among its options.
  test "a restricted context drops tags that don't exist" do
    update(zones: ["", "kitchen", "garage"])

    assert_equal %w[kitchen], @sink.reload.zones_list.to_a
  end

  test "a restricted context accepts existing tags" do
    update(zones: ["", "kitchen"])

    assert_equal %w[kitchen], @sink.reload.zones_list.to_a
  end

  test "the show page and table render the tags as chips" do
    get "/admin/kitchen_sinks/#{@sink.id}"
    assert_includes Nokogiri::HTML(response.body).css("ul.tags li").map { |node| node.text.strip }, "steel"

    get "/admin/kitchen_sinks"
    assert_includes Nokogiri::HTML(response.body).css("td ul.tags li").map { |node| node.text.strip }, "steel"
  end
end
