# frozen_string_literal: true

require "test_helper"

# no_fly_list `has_tags` contexts (KitchenSink: `labels`, and `zones` with
# restrict_to_existing + limit 2), both scoped per organization.
class Plutonium::UI::TagsFieldTest < ActiveSupport::TestCase
  # Defined by `has_tags`, so it only exists once KitchenSink has loaded.
  def tag_class = KitchenSink.const_get(:KitchenSinkTag)

  setup do
    @org = Organization.create!(name: "Org #{SecureRandom.hex(4)}")
    @other_org = Organization.create!(name: "Other #{SecureRandom.hex(4)}")
    tag_class.create!(name: "Sink", organization_id: @other_org.id)
    @sink = KitchenSink.create!(name: "Sink", organization: @org, labels_list: %w[steel shiny])
    tag_class.create!(name: "matte", organization_id: @org.id)
  end

  def form_field(key, record = @sink) = Plutonium::UI::Form::Base.new(record).field(key)

  def select_node(key, record = @sink) = Nokogiri::HTML.fragment(form_field(key, record).component_for(nil).call).at_css("select")

  test "a tag context infers the chip input, not an association select" do
    select = select_node(:labels)

    assert_equal "kitchen_sink[labels][]", select["name"]
    assert_equal "true", select["data-slim-select-addable-value"]
  end

  test "the record's tags are selected" do
    assert_equal %w[steel shiny], select_node(:labels).css("option[selected]").map(&:text)
  end

  test "tags from the record's scope are suggested; other scopes' are not" do
    options = select_node(:labels).css("option").map(&:text)

    assert_includes options, "matte"
    refute_includes options, "Sink"
  end

  test "restrict_to_existing disallows typed tags and limit caps them" do
    select = select_node(:zones)

    assert_nil select["data-slim-select-addable-value"]
    assert_equal "2", select["data-slim-select-max-selected-value"]
  end

  test "submitted tags are extracted to the context's list writer" do
    assert_equal({labels_list: %w[steel brushed]}, form_field(:labels).component_for(nil).extract_input({labels: ["", "steel", "brushed"]}))
  end

  def chips(key, display: Plutonium::UI::Display::Base)
    html = display.new(@sink).field(key).component_for(nil).call
    Nokogiri::HTML.fragment(html).css("li").map { |node| node.text.strip }
  end

  test "the show page renders the tags as chips" do
    assert_equal %w[steel shiny], chips(:labels)
  end

  test "a table cell renders the tags as chips" do
    assert_equal %w[steel shiny], chips(:labels, display: Plutonium::UI::Table::Base::Display)
  end

  test "an untagged context renders nothing" do
    assert_empty chips(:zones)
  end
end
