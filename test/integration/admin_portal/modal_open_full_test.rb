# frozen_string_literal: true

require "test_helper"

# Covers the modal's "open full page" affordance. It began as a show-modal-only
# feature even though `Modal::Base` renders it for any modal — the form pages
# simply never passed `open_full_url:`. It is now offered by :new, :edit and
# interactive actions too.
#
# The link targets a NEW TAB (target=_blank), which is what makes it safe on a
# form: the modal, and anything already typed into it, is left untouched.
class AdminPortal::ModalOpenFullTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  MODAL = {"Turbo-Frame" => Plutonium::REMOTE_MODAL_FRAME}.freeze

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @org = Organization.create!(name: "Sink Org #{SecureRandom.hex(4)}")
    @sink = KitchenSink.create!(name: "Expandable", status: :active, organization: @org)
  end

  teardown { KitchenSink.delete_all }

  def open_full_link(body)
    body[/<a[^>]*aria-label="Open full page in a new tab"[^>]*>/]
  end

  test "show modal offers the open-full link" do
    get "/admin/kitchen_sinks/#{@sink.id}", headers: MODAL
    assert_response :success
    assert open_full_link(response.body), "show modal should offer open-full"
  end

  test "new modal offers the open-full link pointing at its own path" do
    get "/admin/kitchen_sinks/new", headers: MODAL
    assert_response :success
    link = open_full_link(response.body)
    assert link, "new modal should offer open-full"
    assert_includes link, "/admin/kitchen_sinks/new"
  end

  test "edit modal offers the open-full link pointing at its own path" do
    get "/admin/kitchen_sinks/#{@sink.id}/edit", headers: MODAL
    assert_response :success
    link = open_full_link(response.body)
    assert link, "edit modal should offer open-full"
    assert_includes link, "/admin/kitchen_sinks/#{@sink.id}/edit"
  end

  test "interactive action modal offers the open-full link" do
    get "/admin/kitchen_sinks/#{@sink.id}/record_actions/reconfigure", headers: MODAL
    assert_response :success
    assert open_full_link(response.body),
      "an interactive action modal should offer open-full — its GET path renders standalone"
  end

  # Opening in the same tab would discard unsaved input; _blank is the whole
  # reason this is safe to put on a form.
  test "the open-full link opens in a new tab" do
    get "/admin/kitchen_sinks/#{@sink.id}/edit", headers: MODAL
    link = open_full_link(response.body)
    assert_includes link, 'target="_blank"'
    assert_includes link, "noopener"
  end

  # Full-page requests render no modal chrome at all, so there is nothing to
  # expand out of.
  test "a full-page form has no open-full link" do
    get "/admin/kitchen_sinks/#{@sink.id}/edit"
    assert_response :success
    refute open_full_link(response.body),
      "a standalone page is already full — it must not offer to open itself"
  end

  # The interactive action's standalone branch really does render (this is what
  # the expand link lands on).
  test "an interactive action renders standalone when not in a modal" do
    get "/admin/kitchen_sinks/#{@sink.id}/record_actions/reconfigure"
    assert_response :success
    refute open_full_link(response.body)
  end
end
