# frozen_string_literal: true

require "test_helper"

class Plutonium::Query::Filters::TagsTest < ActiveSupport::TestCase
  setup do
    org = Organization.create!(name: "Org #{SecureRandom.hex(4)}")
    @steel = KitchenSink.create!(name: "Steel", organization: org, labels_list: %w[steel])
    @both = KitchenSink.create!(name: "Both", organization: org, labels_list: %w[steel shiny])
    @plain = KitchenSink.create!(name: "Plain", organization: org)
  end

  def apply(value, **options)
    Plutonium::Query::Filters::Tags.new(key: :labels, **options).apply(KitchenSink.all, value:)
  end

  test "is looked up as with: :tags" do
    assert_equal Plutonium::Query::Filters::Tags, Plutonium::Query::Filter.lookup(:tags)
  end

  test "matches records with any of the tags by default" do
    assert_equal [@steel, @both].sort_by(&:id), apply(["", "steel", "shiny"]).sort_by(&:id)
  end

  test "match: :all requires every tag" do
    assert_equal [@both], apply(%w[steel shiny], match: :all).to_a
  end

  test "no tags leaves the scope alone" do
    assert_equal 3, apply([""]).count
  end

  test "the active-filter pill lists the tags" do
    assert_equal "steel, shiny", Plutonium::Query::Filters::Tags.new(key: :labels).humanize_value(["", "steel", "shiny"])
  end
end
