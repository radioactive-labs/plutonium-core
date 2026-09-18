# frozen_string_literal: true

require "test_helper"

# The admin portal wires the i18n layer end to end: the EN | ES links in the
# top bar pass ?locale=, AdminPortal::Concerns::Controller#switch_locale
# remembers it in the session, and Plutonium renders the chosen language.
# Spanish only translates a visible slice of the strings; the rest fall back to
# English (config.i18n.fallbacks), so a switch never trips the test env's
# raise_on_missing_translations.
class AdminPortal::LocaleSwitchTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    login_as_admin(create_admin!)
    create_post!
  end

  test "defaults to English" do
    get "/admin/blogging/posts"

    assert_response :success
    assert_includes response.body, "Search..."
    assert_includes response.body, "Blog Posts"         # lazy page title, en
    refute_includes response.body, "Buscar..."
  end

  test "?locale=es renders the translated chrome" do
    get "/admin/blogging/posts?locale=es"

    assert_response :success
    assert_includes response.body, "Buscar..."          # table search placeholder
    assert_includes response.body, "Cerrar sesión"      # user menu, via nav.sign_out
    assert_includes response.body, "Entradas del blog"  # lazy page title, es
    assert_includes response.body, "Borradores"         # scope tab, via plutonium.scopes
    refute_includes response.body, "Search..."
    refute_includes response.body, "Blog Posts"
  end

  test "the chosen locale persists across later requests" do
    get "/admin/blogging/posts?locale=es"
    assert_includes response.body, "Buscar..."

    # No ?locale this time: the session still carries it.
    get "/admin/blogging/posts"
    assert_includes response.body, "Buscar..."

    # And it can be switched back.
    get "/admin/blogging/posts?locale=en"
    assert_includes response.body, "Search..."
    refute_includes response.body, "Buscar..."
  end

  test "untranslated keys fall back to English instead of raising" do
    # Most Plutonium strings are not translated in es.yml. Under es they must
    # resolve via fallback, not raise: the page renders and an untranslated
    # header string is still shown in English.
    get "/admin/blogging/posts?locale=es"

    assert_response :success
    assert_includes response.body, "Toggle color mode"  # ui.color_mode.toggle, untranslated
  end

  test "the top bar exposes the language toggle" do
    get "/admin/blogging/posts"

    assert_response :success
    assert_match(/lang="es"[^>]*>\s*ES/, response.body)
  end
end
