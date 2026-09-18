# frozen_string_literal: true

require "test_helper"

# A definition may set its page titles and descriptions with the lazy `t`.
# They resolve in the request locale on every surface that renders them: the
# page header and the modal chrome of the show, new and edit pages.
class AdminPortal::LazyPageTitlesTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include I18nTestHelper

  MODAL = {"Turbo-Frame" => Plutonium::REMOTE_MODAL_FRAME}.freeze

  setup do
    login_as_admin(create_admin!)
    @post = create_post!

    store_translations(titles: {
      show: "Post details", blurb: "Everything about this post",
      new: "Draft a post", edit: "Revise the post"
    })
    store_translations({titles: {show: "Detalles de la entrada"}}, locale: :es)

    definition = Blogging::PostDefinition
    definition.show_page_title definition.t("titles.show")
    definition.show_page_description definition.t("titles.blurb")
    definition.new_page_title definition.t("titles.new")
    definition.edit_page_title definition.t("titles.edit")
  end

  teardown do
    definition = Blogging::PostDefinition
    definition.show_page_title nil
    definition.show_page_description nil
    definition.new_page_title nil
    definition.edit_page_title nil
    I18n.backend.reload!
    Plutonium::Translation::Current.reset
  end

  test "lazy titles and descriptions resolve in the page header" do
    get "/admin/blogging/posts/#{@post.id}"
    assert_response :success
    assert_includes response.body, "Post details"
    assert_includes response.body, "Everything about this post"

    get "/admin/blogging/posts/new"
    assert_includes response.body, "Draft a post"

    get "/admin/blogging/posts/#{@post.id}/edit"
    assert_includes response.body, "Revise the post"
  end

  # The modal renders its own heading from the title it is handed, so assert
  # on that element rather than on the page header the frame also carries.
  test "lazy titles and descriptions resolve in the modal chrome" do
    get "/admin/blogging/posts/#{@post.id}", headers: MODAL
    assert_response :success
    assert_modal_title "Post details"
    assert_includes response.body, "Everything about this post"

    get "/admin/blogging/posts/new", headers: MODAL
    assert_modal_title "Draft a post"

    get "/admin/blogging/posts/#{@post.id}/edit", headers: MODAL
    assert_modal_title "Revise the post"
  end

  test "lazy titles follow the request locale" do
    get "/admin/blogging/posts/#{@post.id}?locale=es", headers: MODAL
    assert_modal_title "Detalles de la entrada"
    refute_includes response.body, "Post details"
  end

  private

  def assert_modal_title(text)
    assert_match(%r{<h2 id="pu-modal-title-[^"]+"[^>]*>\s*#{Regexp.escape(text)}\s*</h2>}, response.body)
  end
end
