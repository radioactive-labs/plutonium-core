# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::SecureAssociationChoicesTest < ActiveSupport::TestCase
  setup do
    @acme = Organization.create!(name: "Acme #{SecureRandom.hex(4)}")
    @globex = Organization.create!(name: "Globex #{SecureRandom.hex(4)}")
    @user = User.create!(email: "choices-#{SecureRandom.hex(4)}@example.com", password: "password123")
  end

  def form_field(record, name)
    Plutonium::UI::Form::Base.new(record).field(name)
  end

  def render_input(record, name, tag, **attributes)
    html = form_field(record, name).component_for(tag, skip_authorization: true, add_action: false, **attributes).call
    Nokogiri::HTML.fragment(html)
  end

  def organization_sgid(org) = org.to_signed_global_id.to_s

  test "checkboxes render one checkbox per choice under a collection param" do
    html = render_input(@user, :organizations, :association_checkboxes)
    boxes = html.css("input[type=checkbox]")

    assert_operator boxes.size, :>=, 2
    assert boxes.all? { |box| box["name"] == "user[organizations][]" }
    assert boxes.all? { |box| box["class"].include?("pu-checkbox") }
    assert_equal "group", html.at_css("[role=group]")["role"]
  end

  test "checkboxes label each control with the record" do
    html = render_input(@user, :organizations, :association_checkboxes)
    box = html.css("input[type=checkbox]").find { |input| SignedGlobalID.parse(input["value"]) == @acme.to_signed_global_id }

    assert_equal @acme.to_label, html.at_css("label[for='#{box["id"]}']").text.strip
  end

  test "checkboxes check the current records" do
    @user.organizations << @acme
    html = render_input(@user, :organizations, :association_checkboxes)
    checked = html.css("input[type=checkbox][checked]").map { |box| SignedGlobalID.parse(box["value"]).model_id }

    assert_equal [@acme.id.to_s], checked
  end

  test "checkboxes submit a blank so unchecking everything clears the association" do
    hidden = render_input(@user, :organizations, :association_checkboxes).at_css("input[type=hidden]")

    assert_equal "user[organizations][]", hidden["name"]
    assert_equal "", hidden["value"]
  end

  test "checkboxes extract only authorized sgids" do
    component = form_field(@user, :organizations).component_for(:association_checkboxes, skip_authorization: true, add_action: false)
    extracted = component.extract_input({organizations: ["", organization_sgid(@acme), "forged"]})

    assert_equal [@acme.to_signed_global_id], extracted[:organization_sgids]
  end

  # Disabled boxes aren't submitted; a live blank would clear the association.
  test "a disabled checkbox list disables its blank too" do
    html = render_input(@user, :organizations, :association_checkboxes, disabled: true)

    assert html.at_css("input[type=hidden]")["disabled"]
    assert html.css("input[type=checkbox]").all? { |box| box["disabled"] }
  end

  test "the group is named by the field label" do
    html = render_input(@user, :organizations, :association_checkboxes)
    expected = form_field(@user, :organizations).label

    assert_equal expected, html.at_css("[role=group]")["aria-label"]
  end

  test "toggles render switch-styled checkboxes" do
    boxes = render_input(@user, :organizations, :association_toggles).css("input[type=checkbox]")

    assert boxes.any?
    assert boxes.all? { |box| box["class"].include?("pu-toggle") }
  end

  test "radio buttons render one radio per choice under a singular param" do
    record = KitchenSink.new
    radios = render_input(record, :user, :association_radio_buttons).css("input[type=radio]:not([value=''])")

    assert_operator radios.size, :>=, 1
    assert radios.all? { |radio| radio["name"] == "kitchen_sink[user]" }
    assert radios.all? { |radio| radio["class"].include?("pu-radio") }
  end

  test "radio buttons check the current record" do
    record = KitchenSink.new(user: @user)
    checked = render_input(record, :user, :association_radio_buttons).at_css("input[type=radio][checked]")

    assert_equal @user.to_signed_global_id, SignedGlobalID.parse(checked["value"])
  end

  test "an optional association gets a None choice, selected when empty" do
    html = render_input(KitchenSink.new, :user, :association_radio_buttons)
    none = html.at_css("input[type=radio][value='']")

    assert none
    assert none["checked"]
    assert_equal "None", html.at_css("label[for='#{none["id"]}']").text.strip
    assert_equal "radiogroup", html.at_css("[role=radiogroup]")["role"]
  end

  test "a required association has no None choice and requires a pick" do
    html = render_input(KitchenSink.new, :user, :association_radio_buttons, required: true)

    assert_nil html.at_css("input[type=radio][value='']")
    assert html.css("input[type=radio]").all? { |radio| radio["required"] }
  end

  test "picking None clears the association, a missing param leaves it" do
    component = form_field(KitchenSink.new(user: @user), :user).component_for(:association_radio_buttons, skip_authorization: true, add_action: false)

    assert_equal({user_sgid: ""}, component.extract_input({user: ""}))
    assert_equal({user_sgid: nil}, component.extract_input({}))

    record = KitchenSink.new(user: @user)
    record.user_sgid = ""
    assert_nil record.user
  end

  test "a required association ignores include_blank: true" do
    html = render_input(KitchenSink.new, :user, :association_radio_buttons, required: true, include_blank: true)

    assert_nil html.at_css("input[type=radio][value='']")
  end

  test "include_blank: false drops the None choice" do
    assert_nil render_input(KitchenSink.new, :user, :association_radio_buttons, include_blank: false).at_css("input[type=radio][value='']")
  end

  # A selected record past a cap would not render and be dropped on save.
  test "list variants are capped like the select unless choice_limit is passed" do
    component = form_field(@user, :organizations).component_for(:association_checkboxes)
    assert_equal Plutonium::UI::Form::Components::SecureAssociation::DEFAULT_CHOICE_LIMIT, component.instance_variable_get(:@choice_limit)

    capped = form_field(@user, :organizations).component_for(:association_checkboxes, choice_limit: 1)
    assert_equal 1, capped.instance_variable_get(:@choice_limit)
  end

  test "a capped list still renders the selected records past the cap" do
    @user.organizations << @globex
    html = render_input(@user, :organizations, :association_checkboxes, choices: nil, choice_limit: 1)
    rendered = html.css("input[type=checkbox]").map { |box| SignedGlobalID.parse(box["value"]).model_id }
    checked = html.css("input[type=checkbox][checked]").map { |box| SignedGlobalID.parse(box["value"]).model_id }

    assert_includes rendered, @globex.id.to_s
    assert_equal [@globex.id.to_s], checked
  end

  # Otherwise the browser falls back to the blank option and a save that
  # never touched the field would clear it.
  test "a capped select still renders and selects the current record" do
    current = User.create!(email: "current-#{SecureRandom.hex(4)}@example.com", password: "password123")
    html = render_input(KitchenSink.new(user: current), :user, :belongs_to, choice_limit: 1)
    selected = html.at_css("option[selected]")

    assert_equal 2, html.css("option:not([value=''])").size
    assert_equal current.id.to_s, SignedGlobalID.parse(selected["value"]).model_id
  end

  test "list variants put the caller's attributes on the group and autofocus the first control" do
    html = render_input(@user, :organizations, :association_checkboxes, data: {controller: "picker"}, autofocus: true)
    boxes = html.css("input[type=checkbox]")

    assert_equal "picker", html.at_css("[role=group]")["data-controller"]
    assert boxes.first.key?("autofocus")
    refute boxes.drop(1).any? { |box| box.key?("autofocus") }
    assert_nil html.at_css("[role=group]")["name"]
  end

  test "an empty choice list says so" do
    html = render_input(@user, :organizations, :association_checkboxes, choices: [])

    assert_equal "No options available", html.text.strip
  end

  test "checkboxes reject a singular association" do
    error = assert_raises(ArgumentError) { form_field(KitchenSink.new, :user).component_for(:association_checkboxes) }

    assert_includes error.message, "belongs_to"
  end

  test "radio buttons reject a collection association" do
    assert_raises(ArgumentError) { form_field(@user, :organizations).component_for(:association_radio_buttons) }
  end

  test "list variants reject a polymorphic association" do
    error = assert_raises(ArgumentError) { form_field(Comment.new, :commentable).component_for(:association_radio_buttons) }

    assert_includes error.message, "polymorphic"
  end

  test "list variants reject group_method" do
    error = assert_raises(ArgumentError) { form_field(@user, :organizations).component_for(:association_checkboxes, group_method: :name) }

    assert_includes error.message, "group_method"
  end

  test "builder aliases" do
    builder = Plutonium::UI::Form::Base::Builder

    assert_equal builder.instance_method(:secure_association_checkboxes_tag), builder.instance_method(:association_checkboxes_tag)
    assert_equal builder.instance_method(:secure_association_toggles_tag), builder.instance_method(:association_switches_tag)
    assert_equal builder.instance_method(:secure_association_radio_buttons_tag), builder.instance_method(:association_radios_tag)
  end
end
