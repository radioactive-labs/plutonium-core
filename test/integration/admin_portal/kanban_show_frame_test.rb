# frozen_string_literal: true

require "test_helper"

# Covers the kanban `show_in` board option, which controls the turbo-frame a
# card's show link targets:
#
#   show_in :modal (default) → the remote-modal frame, so a card click opens the
#                              record in the slideover/centered dialog.
#   show_in :page            → "_top", a full-page navigation to the show route.
#
# Both targets escape the column's lazy turbo-frame. The Task board declares
# `show_in :page` (asserted in kanban_column_test); KitchenSink uses the default
# `:modal`, asserted here.
class AdminPortal::KanbanShowFrameTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @org = Organization.create!(name: "Sink Org #{SecureRandom.hex(4)}")
    @sink = KitchenSink.create!(name: "Modal Card", status: :active, organization: @org)
  end

  teardown { KitchenSink.delete_all }

  test "default board (show_in :modal) targets the remote-modal frame" do
    get "/admin/kitchen_sinks?view=kanban&column=active"
    assert_response :success
    assert_includes response.body, "Modal Card", "the seeded card should render in the active column"
    assert_match(/data-turbo-frame="#{Plutonium::REMOTE_MODAL_FRAME}"/, response.body,
      "a card on a show_in :modal board should open the show page in the remote-modal frame")
  end

  test "modal board cards do not target _top" do
    get "/admin/kitchen_sinks?view=kanban&column=active"
    assert_response :success
    # The card's show link is the modal-framed one. (Other links on the card —
    # e.g. the destroy action — legitimately use _top, so we scope the check to
    # the show link's row-click target.)
    show_link = response.body[/<a[^>]*data-row-click-target="show"[^>]*>/]
    assert show_link, "expected a row-click show link on the card"
    assert_includes show_link, %(data-turbo-frame="#{Plutonium::REMOTE_MODAL_FRAME}")
    refute_includes show_link, 'data-turbo-frame="_top"'
  end
end
