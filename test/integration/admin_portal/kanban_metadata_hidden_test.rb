# frozen_string_literal: true

require "test_helper"

# Covers hiding the show-page metadata rail specifically for a kanban card's
# modal. A kanban card and a regular show modal both target the shared
# remote-modal frame, so the card tags its show URL with KANBAN_MODAL_PARAM to
# distinguish itself; the show page then drops the metadata panel for that case
# only, leaving regular modals and full-page shows untouched.
#
# KitchenSinkDefinition declares `metadata :age` and `show_in :modal`, so its
# kanban board opens cards in the modal frame — the exact combination this needs.
# `age` renders as "N years" via a display formatter, giving a stable probe.
class AdminPortal::KanbanMetadataHiddenTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @org = Organization.create!(name: "Sink Org #{SecureRandom.hex(4)}")
    @sink = KitchenSink.create!(name: "Meta Card", status: :active, organization: @org, age: 42)
  end

  teardown { KitchenSink.delete_all }

  test "kanban card show link carries the kanban_modal flag" do
    get "/admin/kitchen_sinks?view=kanban&column=active"
    assert_response :success
    show_link = response.body[/<a[^>]*data-row-click-target="show"[^>]*>/]
    assert show_link, "expected a row-click show link on the card"
    assert_includes show_link, "kanban_modal=1",
      "a kanban card opening in the modal frame should tag its show URL"
  end

  test "grid card show link (modal, but not kanban) does NOT carry the flag" do
    get "/admin/kitchen_sinks?view=grid"
    assert_response :success
    show_link = response.body[/<a[^>]*data-row-click-target="show"[^>]*>/]
    assert show_link, "expected a row-click show link on a grid card"
    refute_includes show_link, "kanban_modal",
      "a regular grid modal is not a kanban modal and must keep its metadata"
  end

  test "opening a card show in the kanban modal hides the metadata panel" do
    get "/admin/kitchen_sinks/#{@sink.id}?kanban_modal=1",
      headers: {"Turbo-Frame" => Plutonium::REMOTE_MODAL_FRAME}
    assert_response :success
    assert_includes response.body, "Meta Card", "the show detail should still render"
    refute_includes response.body, "42 years",
      "the metadata field (age) must be hidden in a kanban card's modal"
  end

  test "a regular show modal keeps the metadata panel" do
    get "/admin/kitchen_sinks/#{@sink.id}",
      headers: {"Turbo-Frame" => Plutonium::REMOTE_MODAL_FRAME}
    assert_response :success
    assert_includes response.body, "42 years",
      "a non-kanban show modal should still show metadata"
  end

  test "full-page show keeps the metadata panel" do
    get "/admin/kitchen_sinks/#{@sink.id}"
    assert_response :success
    assert_includes response.body, "42 years",
      "a full-page show should still show metadata"
  end
end
