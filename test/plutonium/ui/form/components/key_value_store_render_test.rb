# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::KeyValueStoreRenderTest < ActiveSupport::TestCase
  def html
    @html ||= Plutonium::UI::Form::Resource.new(
      KitchenSink.new(prefs: {"newsletter" => "weekly"}),
      resource_fields: [:prefs],
      resource_definition: Plutonium::Definition::Base.new,
      singular_resource: false
    ).field(:prefs).key_value_store_tag.call
  end

  def doc = @doc ||= Nokogiri::HTML5.fragment(html)

  # Hand-rolled input classes skipped the shared input styling (focus ring,
  # invalid state, theme tokens).
  test "pair inputs use the shared input styling" do
    inputs = doc.css("[data-key-value-store-target=keyInput], [data-key-value-store-target=valueInput]")

    refute_empty inputs
    inputs.each { |input| assert_includes input["class"].split, "pu-input" }
  end

  test "remove buttons are labelled for assistive tech" do
    buttons = doc.css("[data-action='key-value-store#removePair']")

    refute_empty buttons
    buttons.each { |button| assert_equal "Remove pair", button["aria-label"] }
  end

  # The add-row <template> was a second hand-copied version of a pair row.
  test "the add-row template matches a rendered pair" do
    rendered = doc.at_css(".key-value-pair")
    template = Nokogiri::HTML5.fragment(doc.at_css("template").inner_html).at_css(".key-value-pair")

    assert_equal rendered["class"], template["class"]
    assert_equal rendered.css("input").map { |i| i["class"] }, template.css("input").map { |i| i["class"] }
    assert_equal "kitchen_sink[prefs][__INDEX__][key]", template.at_css("[data-key-value-store-target=keyInput]")["name"]
  end
end
