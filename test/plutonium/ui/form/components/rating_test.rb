# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::RatingTest < ActiveSupport::TestCase
  def render_input(age: 3, **attributes)
    html = Plutonium::UI::Form::Base.new(KitchenSink.new(age:)).field(:age).component_for(:rating, **attributes).call
    Nokogiri::HTML.fragment(html)
  end

  test "one radio per star, highest first so CSS can fill the stars before the checked one" do
    radios = render_input.css("input[type=radio]:not([value=''])")

    assert_equal %w[5 4 3 2 1], radios.map { |radio| radio["value"] }
    assert radios.all? { |radio| radio["name"] == "kitchen_sink[age]" }
  end

  test "the current value is checked" do
    assert_equal "3", render_input.at_css("input[checked]")["value"]
  end

  test "every star has an accessible label" do
    html = render_input

    assert_equal "radiogroup", html.at_css(".pu-rating")["role"]
    assert_equal "3 out of 5", html.at_css("label[for='#{html.at_css("input[value='3']")["id"]}']").text.strip
  end

  test "max changes the number of stars" do
    assert_equal 10, render_input(max: 10).css("input[type=radio]:not([value=''])").size
  end

  test "the submission is extracted as the chosen number" do
    component = Plutonium::UI::Form::Base.new(KitchenSink.new).field(:age).component_for(:rating)

    assert_equal({age: "4"}, component.extract_input({age: "4"}))
  end

  test "an optional rating can be cleared" do
    clear = render_input.at_css("input[type=radio][value='']")

    assert clear, "expected a clear radio"
    assert_equal "Clear", render_input.at_css("label[for='#{clear["id"]}']").text.strip
  end

  test "clear is selected when there is no rating" do
    assert_equal "", render_input(age: nil).at_css("input[checked]")["value"]
  end

  test "a required rating has no clear option" do
    assert_nil render_input(required: true).at_css("input[type=radio][value='']")
  end

  test "submitting clear extracts a blank" do
    component = Plutonium::UI::Form::Base.new(KitchenSink.new(age: 3)).field(:age).component_for(:rating)

    assert_equal({age: ""}, component.extract_input({age: ""}))
  end
end
