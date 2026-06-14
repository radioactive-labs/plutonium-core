# frozen_string_literal: true

require "test_helper"

# form_layout works in interaction forms too (Form::Interaction < Form::Resource),
# including dynamic options: ReconfigureKitchenSink declares
# `collapsed: -> { object.resource.archived? }`, resolved in the interaction form
# context where `object` is the interaction and `object.resource` the record.
class AdminPortal::FormLayoutInteractionTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @org = Organization.create!(name: "Sink Org #{SecureRandom.hex(4)}")
  end

  def form_for(sink)
    get "/admin/kitchen_sinks/#{sink.id}/record_actions/reconfigure",
      headers: {"Turbo-Frame" => "remote_modal"}
  end

  def appearance_details_tag
    response.body.match(/(<details[^>]*>)\s*<summary[^>]*>\s*Appearance/m)&.[](1)
  end

  test "interaction form renders form_layout sections" do
    sink = KitchenSink.create!(name: "Sink", organization: @org, status: :active)
    form_for(sink)
    assert_response :success
    assert_includes response.body, "Basics"                    # section heading
    assert_includes response.body, "Anything else"             # ungrouped label
    assert_includes response.body, %(name="interaction[name]") # field renders, interaction-keyed
  end

  test "dynamic collapsed: is resolved against object.resource in the interaction" do
    active = KitchenSink.create!(name: "Active", organization: @org, status: :active)
    archived = KitchenSink.create!(name: "Archived", organization: @org, status: :archived)

    form_for(active)
    assert_response :success
    assert_includes appearance_details_tag.to_s, "open",
      "Appearance should be open for a non-archived record"

    form_for(archived)
    assert_response :success
    refute_includes appearance_details_tag.to_s, "open",
      "Appearance should be collapsed for an archived record"
  end
end
