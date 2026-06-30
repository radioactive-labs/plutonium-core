# frozen_string_literal: true

require "test_helper"

# Covers definition-level `show_in :modal` — it makes the :show action open in
# the remote-modal frame from ANY record link (table rows, grid cards), not just
# kanban. KitchenSinkDefinition declares `show_in :modal`; Organization (no
# show_in) keeps the default :page behavior.
class AdminPortal::ShowInModalTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @org = Organization.create!(name: "Sink Org #{SecureRandom.hex(4)}")
    @sink = KitchenSink.create!(name: "Modal Row", status: :active, organization: @org)
  end

  teardown { KitchenSink.delete_all }

  test "table show link targets the remote-modal frame when show_in :modal" do
    get "/admin/kitchen_sinks?view=table"
    assert_response :success
    show_link = response.body[/<a[^>]*data-row-click-target="show"[^>]*>/]
    assert show_link, "expected a row-click show link in the table"
    assert_includes show_link, %(data-turbo-frame="#{Plutonium::REMOTE_MODAL_FRAME}")
  end

  test "grid show link targets the remote-modal frame when show_in :modal" do
    get "/admin/kitchen_sinks?view=grid"
    assert_response :success
    show_link = response.body[/<a[^>]*data-row-click-target="show"[^>]*>/]
    assert show_link, "expected a row-click show link on a grid card"
    assert_includes show_link, %(data-turbo-frame="#{Plutonium::REMOTE_MODAL_FRAME}")
  end

  # A definition with no show_in keeps full-page show links (no modal frame).
  test "default definition (no show_in) keeps full-page show links" do
    get "/admin/organizations?view=table"
    assert_response :success
    show_link = response.body[/<a[^>]*data-row-click-target="show"[^>]*>/]
    assert show_link, "expected a row-click show link for organizations"
    refute_includes show_link, %(data-turbo-frame="#{Plutonium::REMOTE_MODAL_FRAME}"),
      "a definition without show_in :modal should navigate full-page, not open a modal"
  end
end
