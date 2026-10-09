# frozen_string_literal: true

require "test_helper"

# KitchenSinkDefinition declares `field :nicknames, as: :list`.
class AdminPortal::ListFieldTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    login_as_admin(create_admin!)
    @sink = KitchenSink.create!(name: "Sink", organization: Organization.create!(name: "Org #{SecureRandom.hex(4)}"),
      nicknames: %w[Sinky])
  end

  test "the form offers the chip input with the declared suggestions" do
    get "/admin/kitchen_sinks/#{@sink.id}/edit"

    options = Nokogiri::HTML(response.body).css("select[name='kitchen_sink[nicknames][]'] option").map(&:text)
    assert_equal %w[Sinky Basin Tub], options
  end

  test "submitted chips are stored" do
    patch "/admin/kitchen_sinks/#{@sink.id}", params: {kitchen_sink: {name: "Sink", nicknames: ["", "Sinky", "Plughole"]}}

    assert_equal %w[Sinky Plughole], @sink.reload.nicknames
  end

  test "removing every chip clears the list" do
    patch "/admin/kitchen_sinks/#{@sink.id}", params: {kitchen_sink: {name: "Sink", nicknames: [""]}}

    assert_equal [], @sink.reload.nicknames
  end

  test "the show page renders chips" do
    get "/admin/kitchen_sinks/#{@sink.id}"

    assert_equal %w[Sinky], Nokogiri::HTML(response.body).css("ul.list li").map { |node| node.text.strip }
  end
end
