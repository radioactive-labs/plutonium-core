# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Layout::I18nBlobTest < ActiveSupport::TestCase
  # Renders only the locale blob; the full head needs a view context.
  BlobOnly = Class.new(Plutonium::UI::Layout::Base) do
    def view_template = render_i18n
  end

  def blob_json(html)
    JSON.parse(html[%r{<script type="application/json" id="pu-i18n">(.*)</script>}m, 1])
  end

  test "renders the plutonium.js subtree as a JSON script tag" do
    html = BlobOnly.new.call

    assert_includes html, '<script type="application/json" id="pu-i18n">'
    assert_includes html, "Copied!"

    json = blob_json(html)
    assert_equal "Copied!", json.dig("clipboard", "copied")
    assert_equal "Are you sure?", json["are_you_sure"]
    assert_equal({"one" => "Choose file", "other" => "Choose files"}, json.dig("attachment_input", "choose_file"))
    assert_equal "Select Value", json.dig("libraries", "slim_select", "placeholderText")
  end

  test "escapes closing tags inside translated strings" do
    I18n.backend.store_translations(:en, plutonium: {js: {clipboard: {copied: "</script><b>x</b>"}}})
    html = BlobOnly.new.call

    refute_includes html, "</script><b>"
    assert_equal "</script><b>x</b>", blob_json(html).dig("clipboard", "copied")
  ensure
    I18n.backend.store_translations(:en, plutonium: {js: {clipboard: {copied: "Copied!"}}})
  end

  test "stamps the current locale on the html tag" do
    assert_equal "en", Plutonium::UI::Layout::Base.new.send(:html_attributes)[:lang]
  end
end
