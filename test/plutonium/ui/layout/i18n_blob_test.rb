# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Layout::I18nBlobTest < ActiveSupport::TestCase
  include I18nTestHelper

  # Renders only the locale blob; the full head needs a view context.
  BlobOnly = Class.new(Plutonium::UI::Layout::Base) do
    def view_template = render_i18n
  end

  def blob_json(html)
    JSON.parse(CGI.unescapeHTML(html[/<meta name="pu-i18n" content="(.*?)">/m, 1]))
  end

  test "renders the plutonium.js subtree as JSON in a meta tag" do
    html = BlobOnly.new.call

    assert_includes html, '<meta name="pu-i18n" content="'
    assert_includes html, "Copied!"

    json = blob_json(html)
    assert_equal "Copied!", json.dig("clipboard", "copied")
    assert_equal "Are you sure?", json["are_you_sure"]
    assert_equal({"one" => "Choose file", "other" => "Choose files"}, json.dig("attachment_input", "choose_file"))
    assert_equal "Select Value", json.dig("libraries", "slim_select", "placeholderText")
  end

  test "escapes markup inside translated strings" do
    store_translations(plutonium: {js: {clipboard: {copied: "</script><b>x</b>"}}})
    html = BlobOnly.new.call

    refute_includes html, "</script><b>"
    assert_equal "</script><b>x</b>", blob_json(html).dig("clipboard", "copied")
  ensure
    I18n.backend.reload!
  end

  test "a partially translated locale falls back per key to the default locale" do
    store_translations({plutonium: {js: {are_you_sure: "Vraiment ?"}}}, locale: :fr)
    json = with_extra_locale(:fr) { blob_json(BlobOnly.new.call) }

    assert_equal "Vraiment ?", json["are_you_sure"]
    assert_equal "Cancel", json.dig("turbo_confirm", "cancel")
  ensure
    I18n.backend.reload!
  end

  test "stamps the current locale on the html tag" do
    assert_equal "en", Plutonium::UI::Layout::Base.new.send(:html_attributes)[:lang]
  end
end
