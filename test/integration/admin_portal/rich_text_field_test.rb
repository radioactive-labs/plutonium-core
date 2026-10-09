# frozen_string_literal: true

require "test_helper"

# KitchenSink `has_rich_text :notes`, permitted by the policy, undeclared in
# the definition.
class AdminPortal::RichTextFieldTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    login_as_admin(create_admin!)
    @sink = KitchenSink.create!(name: "Sink", organization: Organization.create!(name: "Org #{SecureRandom.hex(4)}"),
      notes: "<p>Rinse <em>daily</em></p>")
  end

  test "the edit form renders the Action Text editor" do
    get "/admin/kitchen_sinks/#{@sink.id}/edit"

    assert_includes response.body, "<trix-editor"
  end

  test "submitted HTML is saved" do
    patch "/admin/kitchen_sinks/#{@sink.id}", params: {kitchen_sink: {name: "Sink", notes: "<p>Scrub <strong>weekly</strong></p>"}}

    assert_includes @sink.reload.notes.body.to_html, "<strong>weekly</strong>"
  end

  test "the show page renders the HTML" do
    get "/admin/kitchen_sinks/#{@sink.id}"

    assert_includes response.body, "Rinse <em>daily</em>"
  end
end
